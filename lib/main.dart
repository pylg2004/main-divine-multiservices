import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/providers.dart';
import 'data/datasources/remote/firestore_sync_service.dart';
import 'features/auth/session_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  await FirestoreSyncService.instance.init();

  final container = ProviderContainer();

  // Config imprimante : seule donnée qui reste locale à l'appareil (voir
  // SettingsRepository) — chaque poste de caisse a sa propre imprimante
  // physique, jamais synchronisée sur Firestore.
  await container.read(settingsRepositoryProvider).loadPrinterFromPrefs();

  await container.read(sessionProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
