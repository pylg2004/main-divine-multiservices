import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/utils/date_formatter.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final logs = ref.watch(auditRepositoryProvider).all();

    return AppShell(
      title: 'Journal d\'audit',
      child: logs.isEmpty
          ? const EmptyState(icon: Icons.history_outlined, title: 'Aucune activité enregistrée')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final log = logs[i];
                return ListTile(
                  leading: const Icon(Icons.circle_notifications_outlined),
                  title: Text(log.action),
                  subtitle: Text('${log.userName}${log.details != null ? ' · ${log.details}' : ''}'),
                  trailing: Text(DateFormatter.dateTime(log.timestamp), style: const TextStyle(fontSize: 12)),
                );
              },
            ),
    );
  }
}
