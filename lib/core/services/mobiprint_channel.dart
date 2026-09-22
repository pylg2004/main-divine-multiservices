import 'package:flutter/services.dart';

/// Pont vers le pilote imprimante intégré natif (voir
/// android/app/.../MobiPrintChannel.kt) — terminaux Android bas de gamme
/// sans SDK ESC/POS type MobiWire MobiPrint 3+ ("Mobilot MP3+"), juste un
/// fichier de commande + /proc/printer. N'existe que côté Android ; sur
/// toute autre plateforme les appels échouent proprement (gérés par
/// ThermalPrinterService).
class MobiPrintChannel {
  static const _channel = MethodChannel('main_divine_multiservices/mobiprint');

  /// Sonde active la disponibilité réelle du pilote (pas une liste blanche
  /// de modèles) — utilisé pour la détection automatique.
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> printText(String text, {int size = 1}) {
    return _channel.invokeMethod('printText', {'text': text, 'size': size});
  }
}
