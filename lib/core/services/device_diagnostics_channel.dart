import 'package:flutter/services.dart';

/// Pont vers DeviceDiagnosticsChannel.kt — lecture seule, sert uniquement à
/// identifier sur un terminal physique inconnu le vrai mécanisme
/// d'impression disponible (périphériques USB bruts, apps système du
/// fabricant, détail exact de l'échec MobiPrint) au lieu de deviner à
/// l'aveugle après un échec. N'existe que côté Android.
class DeviceDiagnosticsChannel {
  static const _channel = MethodChannel('main_divine_multiservices/diagnostics');

  static Future<List<String>> usbDevices() async {
    try {
      final r = await _channel.invokeMethod<List<dynamic>>('usbDevices');
      return r?.cast<String>() ?? const [];
    } catch (e) {
      return ['Erreur : $e'];
    }
  }

  static Future<List<String>> printPackages() async {
    try {
      final r = await _channel.invokeMethod<List<dynamic>>('printPackages');
      return r?.cast<String>() ?? const [];
    } catch (e) {
      return ['Erreur : $e'];
    }
  }

  static Future<List<String>> mobiPrintDebug() async {
    try {
      final r = await _channel.invokeMethod<List<dynamic>>('mobiPrintDebug');
      return r?.cast<String>() ?? const [];
    } catch (e) {
      return ['Erreur : $e'];
    }
  }
}
