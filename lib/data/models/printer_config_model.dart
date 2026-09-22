import 'package:collection/collection.dart';

import 'enums.dart';

/// Enregistrement unique, stocké localement (SharedPreferences, clé
/// `printer_config`) — jamais sur Firestore : chaque poste de caisse a sa
/// propre imprimante physique, donc cette config ne doit pas se propager
/// aux autres appareils (voir SettingsRepository.printer).
class PrinterConfigModel {
  PrinterConnectionType? connectionType;
  String? address; // MAC bluetooth, chemin USB, ou IP réseau
  int? port; // pour réseau
  String? deviceName;
  PrinterPaperWidth paperWidth;

  PrinterConfigModel({
    this.connectionType,
    this.address,
    this.port = 9100,
    this.deviceName,
    this.paperWidth = PrinterPaperWidth.mm58,
  });

  bool get isConfigured =>
      connectionType == PrinterConnectionType.sunmiIntegrated ||
      connectionType == PrinterConnectionType.mobiPrintIntegrated ||
      (connectionType != null && address != null);

  Map<String, dynamic> toJson() => {
        'connectionType': connectionType?.name,
        'address': address,
        'port': port,
        'deviceName': deviceName,
        'paperWidth': paperWidth.name,
      };

  factory PrinterConfigModel.fromJson(Map<String, dynamic> json) {
    return PrinterConfigModel(
      connectionType: PrinterConnectionType.values
          .where((t) => t.name == json['connectionType'])
          .cast<PrinterConnectionType?>()
          .firstOrNull,
      address: json['address'] as String?,
      port: json['port'] as int? ?? 9100,
      deviceName: json['deviceName'] as String?,
      paperWidth: PrinterPaperWidth.values.firstWhere(
        (w) => w.name == json['paperWidth'],
        orElse: () => PrinterPaperWidth.mm58,
      ),
    );
  }
}
