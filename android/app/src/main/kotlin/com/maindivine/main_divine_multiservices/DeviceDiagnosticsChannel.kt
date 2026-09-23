package com.maindivine.main_divine_multiservices

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.hardware.usb.UsbManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile

/**
 * Canal de diagnostic (lecture seule) pour identifier, sur un terminal
 * physique inconnu, le vrai mécanisme d'impression disponible plutôt que de
 * deviner à l'aveugle : liste les périphériques USB bruts vus par le noyau
 * (même ceux qu'un scanner "classe imprimante" ignorerait — utile car le
 * module thermique intégré de certains terminaux n'expose pas la classe USB
 * imprimante standard), les apps système susceptibles d'être le vrai
 * service d'impression du fabricant, et le détail exact (classe + message)
 * de l'échec MobiPrint (permission Unix vs SELinux vs chemin inexistant).
 */
class DeviceDiagnosticsChannel(
    messenger: BinaryMessenger,
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "main_divine_multiservices/diagnostics"
        private const val PROC_PRINTER = "/proc/printer"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "usbDevices" -> result.success(usbDevices())
            "printPackages" -> result.success(printPackages())
            "mobiPrintDebug" -> result.success(mobiPrintDebug())
            else -> result.notImplemented()
        }
    }

    private fun usbDevices(): List<String> {
        val manager = context.getSystemService(Context.USB_SERVICE) as? UsbManager ?: return emptyList()
        val devices = manager.deviceList.values
        if (devices.isEmpty()) return listOf("(aucun périphérique USB détecté par le noyau)")
        return devices.map { d ->
            val interfaces = (0 until d.interfaceCount).joinToString(", ") { i ->
                val iface = d.getInterface(i)
                "classe=${iface.interfaceClass} sousClasse=${iface.interfaceSubclass}"
            }
            "nom=${d.deviceName} vendorId=${d.vendorId} productId=${d.productId} " +
                "classe=${d.deviceClass} sousClasse=${d.deviceSubclass} interfaces=[$interfaces]"
        }
    }

    private fun printPackages(): List<String> {
        val keywords = listOf(
            "print", "pos", "sunmi", "mobi", "escpos", "esc_pos", "thermal",
            "urovo", "newland", "telpo", "pax", "wiseasy", "vanstone", "iware",
            "landi", "verifone", "sdk", "driver",
        )
        val pm = context.packageManager
        return try {
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
                .filter { app ->
                    val pkg = app.packageName.lowercase()
                    val isSystem = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                    isSystem && keywords.any { pkg.contains(it) }
                }
                .map { app ->
                    val label = try {
                        pm.getApplicationLabel(app).toString()
                    } catch (e: Exception) {
                        "?"
                    }
                    "$label (${app.packageName})"
                }
                .ifEmpty { listOf("(aucune app système correspondant aux mots-clés imprimante trouvée)") }
        } catch (e: Exception) {
            listOf("Erreur lors de la liste des apps : ${e.javaClass.simpleName} - ${e.message}")
        }
    }

    private fun mobiPrintDebug(): List<String> {
        val out = mutableListOf<String>()

        out += try {
            RandomAccessFile(PROC_PRINTER, "r").use { it.read(ByteArray(4)) }
            "$PROC_PRINTER : lecture OK"
        } catch (e: Exception) {
            "$PROC_PRINTER : lecture échouée (${e.javaClass.simpleName} - ${e.message})"
        }

        val candidatePaths = listOf(
            "/data/media/printer99.bin",
            "/storage/emulated/0/printer99.bin",
            context.getExternalFilesDir(null)?.let { "${it.absolutePath}/printer99.bin" },
            "${context.filesDir.absolutePath}/printer99.bin",
        ).filterNotNull()

        for (path in candidatePaths) {
            out += try {
                FileOutputStream(path).use { it.write(byteArrayOf(0)) }
                File(path).delete()
                "$path : écriture OK"
            } catch (e: Exception) {
                "$path : écriture échouée (${e.javaClass.simpleName} - ${e.message})"
            }
        }

        return out
    }
}
