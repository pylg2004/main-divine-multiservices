import 'dart:async';

import '../datasources/local/hive_datasource.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/company_settings_model.dart';
import '../models/printer_config_model.dart';

class SettingsRepository {
  static const _companyKey = 'company';
  static const _printerKey = 'printer';

  final _sync = FirestoreSyncService.instance;

  static const _collection = 'settings';

  CompanySettingsModel get company {
    final existing = HiveDatasource.settings.get(_companyKey);
    if (existing is CompanySettingsModel) return existing;
    return CompanySettingsModel();
  }

  Future<void> saveCompany(CompanySettingsModel settings) async {
    await HiveDatasource.settings.put(_companyKey, settings);
    unawaited(_sync.pushDoc(_collection, _companyKey, {
      'name': settings.name,
      'slogan': settings.slogan,
      'phone': settings.phone,
      'address': settings.address,
      'currencyCode': settings.currencyCode,
      'currencySymbol': settings.currencySymbol,
      'logoPath': settings.logoPath,
      'setupComplete': settings.setupComplete,
    }));
  }

  // La config imprimante reste locale à chaque poste (chaque caisse a sa
  // propre imprimante physique) : volontairement jamais synchronisée.
  PrinterConfigModel get printer {
    final existing = HiveDatasource.settings.get(_printerKey);
    if (existing is PrinterConfigModel) return existing;
    return PrinterConfigModel();
  }

  Future<void> savePrinter(PrinterConfigModel config) async {
    await HiveDatasource.settings.put(_printerKey, config);
  }

  bool get isSetupComplete => company.setupComplete;

  /// Récupère les paramètres de l'entreprise depuis Firestore (source de
  /// vérité) et remplace la copie locale. À appeler au démarrage — si
  /// Firestore n'est pas configuré/injoignable ou que rien n'a encore été
  /// synchronisé, la configuration locale existante (ou celle du Setup
  /// Wizard) est conservée telle quelle.
  Future<void> pullFromFirestore() async {
    final data = await _sync.pullDoc(_collection, _companyKey);
    if (data == null) return;
    await HiveDatasource.settings.put(
      _companyKey,
      CompanySettingsModel(
        name: data['name'] as String? ?? 'MAIN DIVINE MULTISERVICES',
        slogan: data['slogan'] as String?,
        phone: data['phone'] as String?,
        address: data['address'] as String?,
        currencyCode: data['currencyCode'] as String? ?? 'HTG',
        currencySymbol: data['currencySymbol'] as String? ?? 'G',
        logoPath: data['logoPath'] as String?,
        setupComplete: data['setupComplete'] as bool? ?? false,
      ),
    );
  }
}
