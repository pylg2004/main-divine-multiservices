import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../shared/permissions/permission.dart';
import '../../shared/permissions/workstation.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/permission_gate.dart';
import '../auth/session_notifier.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final client = ref.watch(clientRepositoryProvider).byId(clientId);
    final session = ref.watch(sessionProvider)!;

    if (client == null) {
      return AppShell(
        title: 'Client introuvable',
        child: const EmptyState(icon: Icons.person_off_outlined, title: 'Ce client a été supprimé'),
      );
    }

    final sales = ref.watch(saleRepositoryProvider).all().where((s) => s.clientId == clientId).toList();

    return AppShell(
      title: client.fullName,
      actions: [
        PermissionGate(
          permission: Permission.clientsCreateEdit,
          child: IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/clients/$clientId/edit'),
          ),
        ),
        PermissionGate(
          permission: Permission.clientsPrintCard,
          child: IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Imprimer la fiche',
            onPressed: () async {
              final company = ref.read(settingsRepositoryProvider).company;
              try {
                final bytes = await ref
                    .read(thermalPrinterServiceProvider)
                    .buildClientCard(client: client, company: company, recentSales: sales);
                await ref.read(thermalPrinterServiceProvider).printBytes(bytes);
                ToastService.success('Fiche imprimée');
              } catch (e) {
                ToastService.error(e.toString());
              }
            },
          ),
        ),
        PermissionGate(
          permission: Permission.clientsDelete,
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Supprimer le client',
                message: 'Cette action est irréversible.',
                danger: true,
              );
              if (ok) {
                await ref.read(clientRepositoryProvider).delete(clientId);
                ref.read(dataRevisionProvider.notifier).state++;
                if (context.mounted) context.pop();
              }
            },
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(radius: 24, child: Icon(Icons.person, size: 28)),
                    title: Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(client.phone),
                  ),
                  if (client.email != null && client.email!.isNotEmpty) Text('Email: ${client.email}'),
                  Text('Client depuis: ${DateFormatter.date(client.createdAt)}'),
                  if (client.notes != null && client.notes!.isNotEmpty) ...[
                    const Divider(),
                    const Text('Notes / préférences', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(client.notes!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(child: _statTile(context, 'Total dépensé', MoneyFormatter.format(client.totalSpent))),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: _statTile(context, 'Points fidélité', '${client.loyaltyPoints}')),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: _statTile(context, 'Visites', '${sales.length}')),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text('Historique (POS + Beauté)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
              child: EmptyState(icon: Icons.receipt_long_outlined, title: 'Aucune visite pour le moment'),
            )
          else
            ...sales.map((s) => Card(
                  child: ListTile(
                    leading: Icon(s.workstation.icon, color: s.workstation.color),
                    title: Text('${s.id} — ${MoneyFormatter.format(s.total)}'),
                    subtitle: Text(DateFormatter.dateTime(s.date)),
                    trailing: Text(session.can(Permission.salesViewAll) || s.sellerId == session.user.id
                        ? s.workstation.label
                        : ''),
                    onTap: () => context.push('/sales/${s.id}'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.sm),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
