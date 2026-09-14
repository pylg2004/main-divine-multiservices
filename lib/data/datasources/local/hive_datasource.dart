import 'package:hive_flutter/hive_flutter.dart';

import '../../models/audit_log_model.dart';
import '../../models/beauty_service_model.dart';
import '../../models/client_model.dart';
import '../../models/company_settings_model.dart';
import '../../models/enums.dart';
import '../../models/print_service_model.dart';
import '../../models/printer_config_model.dart';
import '../../models/product_model.dart';
import '../../models/sale_item_model.dart';
import '../../models/sale_model.dart';
import '../../models/user_model.dart';

/// Ouvre toutes les boxes Hive utilisées par l'application. La base démarre
/// toujours vide — aucune donnée n'est injectée ici (voir règle §1 du
/// prompt : aucun produit/client/vente/service pré-enregistré).
class HiveDatasource {
  HiveDatasource._();

  static const String usersBox = 'users';
  static const String productsBox = 'products';
  static const String beautyServicesBox = 'beauty_services';
  static const String printServicesBox = 'print_services';
  static const String clientsBox = 'clients';
  static const String salesBox = 'sales';
  static const String auditLogsBox = 'audit_logs';
  static const String settingsBox = 'settings';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    Hive.registerAdapter(UserRoleAdapter());
    Hive.registerAdapter(WorkstationAdapter());
    Hive.registerAdapter(ProductCategoryAdapter());
    Hive.registerAdapter(BeautyServiceCategoryAdapter());
    Hive.registerAdapter(SaleItemTypeAdapter());
    Hive.registerAdapter(SaleStatusAdapter());
    Hive.registerAdapter(PaymentMethodAdapter());
    Hive.registerAdapter(PrinterConnectionTypeAdapter());
    Hive.registerAdapter(PrinterPaperWidthAdapter());
    Hive.registerAdapter(PrintServiceCategoryAdapter());

    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(BeautyServiceModelAdapter());
    Hive.registerAdapter(PrintServiceModelAdapter());
    Hive.registerAdapter(ClientModelAdapter());
    Hive.registerAdapter(SaleItemModelAdapter());
    Hive.registerAdapter(SaleModelAdapter());
    Hive.registerAdapter(AuditLogModelAdapter());
    Hive.registerAdapter(CompanySettingsModelAdapter());
    Hive.registerAdapter(PrinterConfigModelAdapter());

    await Future.wait([
      Hive.openBox<UserModel>(usersBox),
      Hive.openBox<ProductModel>(productsBox),
      Hive.openBox<BeautyServiceModel>(beautyServicesBox),
      Hive.openBox<PrintServiceModel>(printServicesBox),
      Hive.openBox<ClientModel>(clientsBox),
      Hive.openBox<SaleModel>(salesBox),
      Hive.openBox<AuditLogModel>(auditLogsBox),
      Hive.openBox(settingsBox),
    ]);

    _initialized = true;
  }

  static Box<UserModel> get users => Hive.box<UserModel>(usersBox);
  static Box<ProductModel> get products => Hive.box<ProductModel>(productsBox);
  static Box<BeautyServiceModel> get beautyServices =>
      Hive.box<BeautyServiceModel>(beautyServicesBox);
  static Box<PrintServiceModel> get printServices =>
      Hive.box<PrintServiceModel>(printServicesBox);
  static Box<ClientModel> get clients => Hive.box<ClientModel>(clientsBox);
  static Box<SaleModel> get sales => Hive.box<SaleModel>(salesBox);
  static Box<AuditLogModel> get auditLogs =>
      Hive.box<AuditLogModel>(auditLogsBox);
  static Box get settings => Hive.box(settingsBox);
}
