import '../datasources/local/hive_datasource.dart';
import '../models/company_settings_model.dart';
import '../models/printer_config_model.dart';

class SettingsRepository {
  static const _companyKey = 'company';
  static const _printerKey = 'printer';

  CompanySettingsModel get company {
    final existing = HiveDatasource.settings.get(_companyKey);
    if (existing is CompanySettingsModel) return existing;
    return CompanySettingsModel();
  }

  Future<void> saveCompany(CompanySettingsModel settings) async {
    await HiveDatasource.settings.put(_companyKey, settings);
  }

  PrinterConfigModel get printer {
    final existing = HiveDatasource.settings.get(_printerKey);
    if (existing is PrinterConfigModel) return existing;
    return PrinterConfigModel();
  }

  Future<void> savePrinter(PrinterConfigModel config) async {
    await HiveDatasource.settings.put(_printerKey, config);
  }

  bool get isSetupComplete => company.setupComplete;
}
