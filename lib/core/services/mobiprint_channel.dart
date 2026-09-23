import 'package:flutter/services.dart';

/// Pont vers le vrai service système d'impression de certains terminaux
/// Android bas de gamme sans SDK ESC/POS public (constaté sur MobiWire
/// MobiPrint 3+ / "Mobilot MP3+") — voir
/// android/.../MobiPrintChannel.kt pour le détail de l'interface AIDL
/// (`com.mobiwire.printraw.PrintIOInterface`, reconstruite par analyse du
/// bytecode dex du service `com.mobiwire.printraw` installé sur l'appareil,
/// car aucun SDK public n'est documenté par le fabricant). N'existe que
/// côté Android ; sur toute autre plateforme les appels échouent proprement
/// (gérés par ThermalPrinterService).
class MobiPrintChannel {
  static const _channel = MethodChannel('main_divine_multiservices/mobiprint');

  /// Sonde si le service `com.mobiwire.printraw` est installé sur ce
  /// terminal (résolution du service, pas de connexion active) — utilisé
  /// pour la détection automatique.
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Envoie des octets ESC/POS bruts au service via son interface AIDL
  /// `transmit(byte[], int)` (après `powerOn(true)`) — voir
  /// MobiPrintChannel.kt.
  static Future<void> printBytes(List<int> bytes) async {
    await _channel.invokeMethod('printBytes', {'bytes': bytes});
  }
}
