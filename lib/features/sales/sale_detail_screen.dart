import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/qty_formatter.dart';
import '../../data/models/enums.dart';
import '../../shared/permissions/permission.dart';
import '../../shared/permissions/workstation.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/permission_gate.dart';
import '../auth/session_notifier.dart';

class SaleDetailScreen extends ConsumerWidget {
  final String saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  String _paymentLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.especes:
        return 'Espèces';
      case PaymentMethod.carte:
        return 'Carte';
      case PaymentMethod.mobile:
        return 'Mobile';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final sale = ref.watch(saleRepositoryProvider).byId(saleId);
    final session = ref.watch(sessionProvider)!;

    if (sale == null) {
      return AppShell(
        title: 'Vente introuvable',
        child: const EmptyState(icon: Icons.receipt_long_outlined, title: 'Cette vente est introuvable'),
      );
    }

    final cancelled = sale.status == SaleStatus.annulee;

    return AppShell(
      title: sale.id,
      actions: [
        PermissionGate(
          permission: Permission.salesPrint,
          child: IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final company = ref.read(settingsRepositoryProvider).company;
              try {
                await ref.read(thermalPrinterServiceProvider).printSaleReceipt(sale: sale, company: company);
                ToastService.success('Reçu imprimé');
              } catch (e) {
                ToastService.error(e.toString());
              }
            },
          ),
        ),
        if (!cancelled)
          PermissionGate(
            permission: Permission.salesCancel,
            child: IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Annuler la vente',
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Annuler la vente',
                  message: 'Voulez-vous vraiment annuler ${sale.id} ?',
                  danger: true,
                );
                if (ok) {
                  await ref.read(saleRepositoryProvider).cancel(sale.id);
                  await ref.read(auditServiceProvider).log(session.user, 'Vente annulée', details: sale.id);
                  ref.read(dataRevisionProvider.notifier).state++;
                }
              },
            ),
          ),
        PermissionGate(
          permission: Permission.salesDelete,
          child: IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: 'Supprimer définitivement',
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Supprimer la vente',
                message: 'Action irréversible — la vente sera définitivement supprimée.',
                danger: true,
              );
              if (ok) {
                await ref.read(saleRepositoryProvider).delete(sale.id);
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
          if (cancelled)
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              margin: const EdgeInsets.only(bottom: AppSizes.md),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Text('Vente annulée', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ]),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(sale.workstation.icon, color: sale.workstation.color),
                    const SizedBox(width: 8),
                    Text(sale.workstation.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(),
                  Text('Date: ${DateFormatter.dateTime(sale.date)}'),
                  Text('Client: ${sale.clientName}'),
                  if (sale.clientPhone.isNotEmpty) Text('Tél: ${sale.clientPhone}'),
                  Text('Servi par: ${sale.sellerName}'),
                  Text('Paiement: ${_paymentLabel(sale.paymentMethod)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Card(
            child: Column(
              children: [
                for (final item in sale.items)
                  ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      '${QtyFormatter.format(item.qty, fractional: QtyFormatter.isFractionalUnit(item.unit))}'
                      '${QtyFormatter.isFractionalUnit(item.unit) ? ' ${item.unit}' : ''}'
                      ' × ${MoneyFormatter.format(item.unitPrice)}'
                      '${item.hasBulkDiscount ? ' · -10% (quantité ≥ 3)' : ''}',
                      style: item.hasBulkDiscount
                          ? const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)
                          : null,
                    ),
                    trailing: Text(MoneyFormatter.format(item.sum)),
                  ),
                const Divider(height: 1),
                ListTile(title: const Text('Sous-total'), trailing: Text(MoneyFormatter.format(sale.subtotal))),
                if (sale.discount > 0)
                  ListTile(title: const Text('Remise'), trailing: Text('-${MoneyFormatter.format(sale.discount)}')),
                ListTile(
                  title: const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    MoneyFormatter.format(sale.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
