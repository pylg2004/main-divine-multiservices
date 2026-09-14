import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/audit_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/beauty_service_repository.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/print_service_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/sale_repository.dart';
import '../data/repositories/settings_repository.dart';
import 'services/audit_service.dart';
import 'services/thermal_printer_service.dart';

/// Providers des repositories — un seul point d'instanciation, réutilisé
/// par toutes les features. Les repositories eux-mêmes sont des classes
/// simples (pas de StateNotifier) : l'état réactif vit dans les providers
/// de chaque feature (ex. sessionProvider), pas ici.
final authRepositoryProvider = Provider((ref) => AuthRepository());
final productRepositoryProvider = Provider((ref) => ProductRepository());
final beautyServiceRepositoryProvider =
    Provider((ref) => BeautyServiceRepository());
final printServiceRepositoryProvider =
    Provider((ref) => PrintServiceRepository());
final clientRepositoryProvider = Provider((ref) => ClientRepository());
final saleRepositoryProvider = Provider((ref) => SaleRepository());
final auditRepositoryProvider = Provider((ref) => AuditRepository());
final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final auditServiceProvider = Provider((ref) {
  return AuditService(ref.watch(auditRepositoryProvider));
});

final thermalPrinterServiceProvider = Provider((ref) {
  return ThermalPrinterService(ref.watch(settingsRepositoryProvider));
});

/// Incrémenté après chaque mutation de données (vente, client, produit...)
/// pour permettre aux écrans de liste/dashboard de se rafraîchir sans
/// dépendre d'un flux Hive par box.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

/// Valeur initiale lue une fois depuis Hive ; le Setup Wizard bascule
/// explicitement cet état à `true` à la fin de l'étape 4 (voir
/// features/setup) plutôt que de re-sonder la box en continu.
final setupCompleteProvider = StateProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).isSetupComplete;
});
