package com.maindivine.main_divine_multiservices

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.DeadObjectException
import android.os.IBinder
import com.mobiwire.printraw.PrintIOInterface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pont vers le vrai service système d'impression de certains terminaux
 * Android bas de gamme sans SDK ESC/POS public (constaté sur MobiWire
 * MobiPrint 3+ / "Mobilot MP3+", package système `com.mobiwire.printraw` /
 * service `.PrintRawIOService`) : aucun SDK public n'étant documenté par le
 * fabricant, cette interface AIDL a été reconstruite en analysant le
 * bytecode dex du service réel installé sur l'appareil (voir
 * android/app/src/main/aidl/com/mobiwire/printraw/PrintIOInterface.aidl —
 * l'ORDRE des méthodes y a été préservé à l'identique de l'original, ce qui
 * est indispensable : AIDL numérote les transactions Binder par ordre de
 * déclaration, pas par nom).
 *
 * Un ancien mécanisme (fichier de commande + /proc/printer, voir
 * l'historique git) écrivait directement sur le disque : il échouait
 * systématiquement ("Permission denied") sur le firmware actuel de ce
 * terminal, /data/media n'étant plus accessible à une app tierce sur
 * Android récent (restriction Unix de base, pas du scoped storage
 * contournable). Le vrai canal, confirmé par un test d'impression réussi
 * depuis les paramètres système du terminal, passe par ce service.
 */
class MobiPrintChannel(messenger: BinaryMessenger, private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "main_divine_multiservices/mobiprint"
        private const val SERVICE_PACKAGE = "com.mobiwire.printraw"
        private const val SERVICE_ACTION = "sagereal.intent.action.CONN_PRINTIO_SERVICE_AIDL"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var service: PrintIOInterface? = null
    private var connection: ServiceConnection? = null
    private var bindInFlight = false
    private val pendingCallbacks = mutableListOf<(PrintIOInterface?) -> Unit>()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        resetConnection()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isAvailable())
            "printBytes" -> {
                @Suppress("UNCHECKED_CAST")
                val bytes = (call.argument<List<Int>>("bytes") ?: emptyList()).map { it.toByte() }.toByteArray()
                print(bytes, result, retriesLeft = 1)
            }
            else -> result.notImplemented()
        }
    }

    private fun print(bytes: ByteArray, result: MethodChannel.Result, retriesLeft: Int) {
        withService { svc ->
            if (svc == null) {
                result.error("MOBIPRINT_ERROR", "Service d'impression introuvable ou indisponible.", null)
                return@withService
            }
            try {
                svc.powerOn(true)
                svc.transmit(bytes, bytes.size)
                result.success(null)
            } catch (e: DeadObjectException) {
                // Le service a redémarré depuis la connexion : le lien en cache est mort.
                resetConnection()
                if (retriesLeft > 0) {
                    print(bytes, result, retriesLeft - 1)
                } else {
                    result.error("MOBIPRINT_ERROR", "Service d'impression indisponible (redémarrage en cours).", null)
                }
            } catch (e: Exception) {
                result.error("MOBIPRINT_ERROR", "${e.javaClass.simpleName} - ${e.message}", null)
            }
        }
    }

    private fun resetConnection() {
        connection?.let {
            try {
                context.unbindService(it)
            } catch (_: Exception) {
            }
        }
        connection = null
        service = null
        bindInFlight = false
    }

    /** Résolution du service (rapide, synchrone) — pas de connexion active nécessaire. */
    private fun isAvailable(): Boolean {
        val intent = Intent(SERVICE_ACTION).apply { setPackage(SERVICE_PACKAGE) }
        return context.packageManager.resolveService(intent, 0) != null
    }

    /**
     * Fournit l'interface connectée à [callback], en la liant à la demande.
     * Ne bloque jamais le thread appelant (le binding Android est
     * intrinsèquement asynchrone — bloquer en attendant onServiceConnected
     * depuis le thread principal provoquerait un blocage permanent, ce
     * callback étant lui-même distribué sur ce même thread).
     */
    private fun withService(callback: (PrintIOInterface?) -> Unit) {
        service?.let { callback(it); return }
        synchronized(pendingCallbacks) { pendingCallbacks.add(callback) }
        if (bindInFlight) return
        bindInFlight = true

        val conn = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                service = PrintIOInterface.Stub.asInterface(binder)
                bindInFlight = false
                flushPending()
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                service = null
            }
        }
        connection = conn

        val intent = Intent(SERVICE_ACTION).apply { setPackage(SERVICE_PACKAGE) }
        val bound = try {
            context.bindService(intent, conn, Context.BIND_AUTO_CREATE)
        } catch (e: Exception) {
            false
        }
        if (!bound) {
            bindInFlight = false
            connection = null
            flushPending()
        }
    }

    private fun flushPending() {
        val callbacks = synchronized(pendingCallbacks) {
            val list = pendingCallbacks.toList()
            pendingCallbacks.clear()
            list
        }
        callbacks.forEach { it(service) }
    }
}
