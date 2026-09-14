import 'package:hive/hive.dart';

import 'enums.dart';

part 'printer_config_model.g.dart';

/// Enregistrement unique (clé fixe 'printer') stocké dans la box settings.
@HiveType(typeId: 8)
class PrinterConfigModel extends HiveObject {
  @HiveField(0)
  PrinterConnectionType? connectionType;
  @HiveField(1)
  String? address; // MAC bluetooth, chemin USB, ou IP réseau
  @HiveField(2)
  int? port; // pour réseau
  @HiveField(3)
  String? deviceName;
  @HiveField(4)
  PrinterPaperWidth paperWidth;

  PrinterConfigModel({
    this.connectionType,
    this.address,
    this.port = 9100,
    this.deviceName,
    this.paperWidth = PrinterPaperWidth.mm58,
  });

  bool get isConfigured => connectionType != null && address != null;
}
