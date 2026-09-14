import 'package:hive/hive.dart';

part 'company_settings_model.g.dart';

/// Enregistrement unique (clé fixe 'company') stocké dans la box settings.
@HiveType(typeId: 7)
class CompanySettingsModel extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String? slogan;
  @HiveField(2)
  String? phone;
  @HiveField(3)
  String? address;
  @HiveField(4)
  String currencyCode;
  @HiveField(5)
  String currencySymbol;
  @HiveField(6)
  String? logoPath;
  @HiveField(7)
  bool setupComplete;

  CompanySettingsModel({
    this.name = 'MAIN DIVINE MULTISERVICES',
    this.slogan,
    this.phone,
    this.address,
    this.currencyCode = 'HTG',
    this.currencySymbol = 'G',
    this.logoPath,
    this.setupComplete = false,
  });
}
