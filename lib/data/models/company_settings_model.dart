/// Enregistrement unique (document Firestore `settings/company`).
class CompanySettingsModel {
  String name;
  String? slogan;
  String? phone;
  String? address;
  String currencyCode;
  String currencySymbol;
  String? logoPath;
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
