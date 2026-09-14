import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'data/datasources/local/hive_datasource.dart';
import 'features/auth/session_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatasource.init();
  await initializeDateFormatting('fr');

  final container = ProviderContainer();
  await container.read(sessionProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
