import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../data/models/enums.dart';
import '../../data/models/sale_model.dart';
import '../../shared/permissions/permission.dart';
import '../../shared/permissions/workstation.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../auth/session_notifier.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  final bool ownOnly;
  const SalesListScreen({super.key, this.ownOnly = false});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  Workstation? _workstationFilter;
  SaleStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final session = ref.watch(sessionProvider)!;
    final isAdmin = session.workstation == Workstation.admin;

    var sales = ref.watch(saleRepositoryProvider).all();

    if (!isAdmin) {
      sales = sales.where((s) => s.workstation == session.workstation).toList();
    }
    final showOwnOnly = widget.ownOnly || !session.can(Permission.salesViewAll);
    if (showOwnOnly) {
      sales = sales.where((s) => s.sellerId == session.user.id).toList();
    }
    if (_workstationFilter != null) {
      sales = sales.where((s) => s.workstation == _workstationFilter).toList();
    }
    if (_statusFilter != null) {
      sales = sales.where((s) => s.status == _statusFilter).toList();
    }

    return AppShell(
      title: showOwnOnly ? 'Mes ventes' : 'Ventes',
      child: Column(
        children: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tous les postes'),
                      selected: _workstationFilter == null,
                      onSelected: (_) => setState(() => _workstationFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('POS'),
                      selected: _workstationFilter == Workstation.pos,
                      onSelected: (_) => setState(() => _workstationFilter = Workstation.pos),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Beauté'),
                      selected: _workstationFilter == Workstation.beauty,
                      onSelected: (_) => setState(() => _workstationFilter = Workstation.beauty),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Impression'),
                      selected: _workstationFilter == Workstation.impression,
                      onSelected: (_) => setState(() => _workstationFilter = Workstation.impression),
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Annulées uniquement'),
                      selected: _statusFilter == SaleStatus.annulee,
                      onSelected: (sel) => setState(() => _statusFilter = sel ? SaleStatus.annulee : null),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: sales.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Aucune vente')
                : ListView.separated(
                    itemCount: sales.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _SaleTile(sale: sales[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final SaleModel sale;
  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final cancelled = sale.status == SaleStatus.annulee;
    return ListTile(
      leading: Icon(sale.workstation.icon, color: cancelled ? Colors.grey : sale.workstation.color),
      title: Text(
        '${sale.id} — ${sale.clientName}',
        style: TextStyle(decoration: cancelled ? TextDecoration.lineThrough : null),
      ),
      subtitle: Text('${DateFormatter.dateTime(sale.date)} · ${sale.sellerName}'),
      trailing: Text(
        MoneyFormatter.format(sale.total),
        style: TextStyle(fontWeight: FontWeight.bold, color: cancelled ? Colors.grey : null),
      ),
      onTap: () => context.push('/sales/${sale.id}'),
    );
  }
}
