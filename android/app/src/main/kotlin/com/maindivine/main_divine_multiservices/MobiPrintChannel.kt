package com.maindivine.main_divine_multiservices

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.charset.Charset

/**
 * Pont vers le pilote imprimante intégré de certains terminaux Android bas
 * de gamme sans SDK ni service AIDL (constaté sur MobiWire MobiPrint 3+ /
 * "Mobilot MP3+") : le pilote noyau attend un fichier de commande texte
 * déposé sur le disque, puis un signal écrit dans le pseudo-fichier
 * /proc/printer pour déclencher l'impression. Ce mécanisme est propre au
 * pilote noyau de ce type de terminal (rien à voir avec ESC/POS), d'où un
 * canal dédié plutôt qu'une réutilisation du flux d'octets ESC/POS
 * existant (voir ThermalPrinterService._printMobiPrintText côté Dart).
 *
 * Accès à /data/media et /proc/printer : ces chemins ne sont normalement
 * pas accessibles à une app sandboxée sur Android récent (SELinux). Ce
 * canal ne fonctionne donc que sur un firmware OEM qui les rend
 * délibérément accessibles aux apps tierces (le cas visé ici) — sinon
 * [isAvailable] renvoie simplement false.
 */
class MobiPrintChannel(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "main_divine_multiservices/mobiprint"
        private const val PROC_PRINTER = "/proc/printer"
        private const val DATA_FILE_PREFIX = "/data/media/printer"
        private const val DATA_FILE_EXT = ".bin"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var targetIndex = 0

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isAvailable())
            "printText" -> {
                val text = call.argument<String>("text") ?: ""
                val size = (call.argument<Int>("size") ?: 1).coerceIn(1, 4)
                try {
                    printText(text, size)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("MOBIPRINT_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Sonde la disponibilité réelle du pilote plutôt que de se fier au nom de l'appareil. */
    private fun isAvailable(): Boolean {
        return try {
            RandomAccessFile(PROC_PRINTER, "r").use { it.read(ByteArray(4)) }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun printText(text: String, size: Int) {
        val header = byteArrayOf(
            29, 96,
            'P'.code.toByte(), 'R'.code.toByte(), 'I'.code.toByte(), 'N'.code.toByte(), 'T'.code.toByte(),
            1, size.toByte(), 0,
        )
        val encoded = text.toByteArray(Charset.forName("UTF-16"))
        // UTF-16 avec BOM (2 premiers octets) — le pilote attend le texte sans BOM.
        val body = if (encoded.size > 2) encoded.copyOfRange(2, encoded.size) else encoded
        val path = nextDataFile()
        FileOutputStream(path).use { fos ->
            fos.write(header)
            fos.write(body)
        }
        FileOutputStream(PROC_PRINTER).use { fos ->
            fos.write(path.toByteArray())
        }
    }

    private fun nextDataFile(): String {
        val path = "$DATA_FILE_PREFIX$targetIndex$DATA_FILE_EXT"
        targetIndex = (targetIndex + 1) % 50
        val file = File(path)
        if (file.exists()) file.delete()
        return path
    }
}
