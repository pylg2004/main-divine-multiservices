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
  await container.read(sessionProvider.notifier).restore();
  // Firestore est la base prioritaire : on rapatrie le catalogue avant
  // d'afficher l'UI. Si Firestore n'est pas configuré/injoignable, le
  // cache local (Hive) déjà chargé reste utilisé tel quel.
  await container.read(productRepositoryProvider).pullFromFirestore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
