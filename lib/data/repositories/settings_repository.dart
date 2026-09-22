import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../datasources/remote/firestore_sync_service.dart';
import '../models/company_settings_model.dart';
import '../models/printer_config_model.dart';

class SettingsRepository {
  static const _printerPrefsKey = 'printer_config';

  final _sync = FirestoreSyncService.instance;

  static const _collection = 'settings';
  static const _companyKey = 'company';

  CompanySettingsModel _company = CompanySettingsModel();
  CompanySettingsModel get company => _company;

  Future<void> saveCompany(CompanySettingsModel settings) async {
    _company = settings;
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
  // propre imprimante physique) : volontairement jamais synchronisée sur
  // Firestore, stockée via SharedPreferences (le seul stockage local
  // restant dans l'app — voir choix "Firestore = seule base de données"
  // pour tout le reste).
  PrinterConfigModel _printer = PrinterConfigModel();
  PrinterConfigModel get printer => _printer;

  Future<void> loadPrinterFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_printerPrefsKey);
    if (raw == null) return;
    try {
      _printer = PrinterConfigModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _printer = PrinterConfigModel();
    }
  }

  Future<void> savePrinter(PrinterConfigModel config) async {
    _printer = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerPrefsKey, jsonEncode(config.toJson()));
  }

  bool get isSetupComplete => company.setupComplete;

  /// Récupère les paramètres de l'entreprise depuis Firestore (seule base
  /// de données) et remplace la copie en mémoire. À appeler après
  /// connexion — si Firestore est injoignable ou que rien n'a encore été
  /// synchronisé, la configuration par défaut (ou celle du Setup Wizard)
  /// reste utilisée.
  Future<void> pullFromFirestore() async {
    final data = await _sync.pullDoc(_collection, _companyKey);
    if (data == null) return;
    _company = CompanySettingsModel(
      name: data['name'] as String? ?? 'MAIN DIVINE MULTISERVICES',
      slogan: data['slogan'] as String?,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      currencyCode: data['currencyCode'] as String? ?? 'HTG',
      currencySymbol: data['currencySymbol'] as String? ?? 'G',
      logoPath: data['logoPath'] as String?,
      setupComplete: data['setupComplete'] as bool? ?? false,
    );
  }
}
