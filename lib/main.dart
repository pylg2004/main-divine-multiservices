import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/providers.dart';
import 'data/datasources/local/hive_datasource.dart';
import 'data/datasources/remote/firestore_sync_service.dart';
import 'features/auth/session_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatasource.init();
  await initializeDateFormatting('fr');
  await FirestoreSyncService.instance.init();

  final container = ProviderContainer();

  // Firestore est la base prioritaire pour toutes les données métier : on
  // rapatrie tout avant d'afficher l'UI — y compris avant de restaurer la
  // session, qui dépend des utilisateurs déjà chargés localement. Si
  // Firestore n'est pas configuré ou injoignable, le cache local (Hive)
  // déjà chargé reste utilisé tel quel (aucune régression du mode
  // 100% hors-ligne).
  await Future.wait([
    container.read(authRepositoryProvider).pullFromFirestore(),
    container.read(productRepositoryProvider).pullFromFirestore(),
    container.read(clientRepositoryProvider).pullFromFirestore(),
    container.read(beautyServiceRepositoryProvider).pullFromFirestore(),
    container.read(printServiceRepositoryProvider).pullFromFirestore(),
    container.read(saleRepositoryProvider).pullFromFirestore(),
    container.read(settingsRepositoryProvider).pullFromFirestore(),
    container.read(auditRepositoryProvider).pullFromFirestore(),
  ]);

  await container.read(sessionProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
