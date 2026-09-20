import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/qty_formatter.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/sale_model.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/stat_grid.dart';
import '../../auth/session_notifier.dart';
import '../../catalog/products/products_list_screen.dart';

/// Tableau de bord du "Vendeur Boissons" : mêmes indicateurs que les autres
/// postes dédiés, mais limités aux ventes du poste [Workstation.boisson] et
/// au stock des produits de catégorie [ProductCategory.boisson] (voir le
/// filtre correspondant dans sale_screen.dart `_catalogFor`).
class BoissonDashboardScreen extends ConsumerWidget {
  const BoissonDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final session = ref.watch(sessionProvider)!;
    final today = DateFormatter.startOfDay(DateTime.now());

    final allSales = ref.watch(saleRepositoryProvider).byWorkstation(Workstation.boisson);
    final todaySales = allSales.where((s) => !s.date.isBefore(today) && s.status == SaleStatus.complete).toList();
    final revenue = todaySales.fold<double>(0, (sum, s) => sum + s.total);

    final products =
        ref.watch(productsListProvider).where((p) => p.category == ProductCategory.boisson).toList();
    final lowStock = products.where((p) => p.active && p.stock <= 3).toList();

    final topCounts = <String, double>{};
    for (final s in todaySales) {
      for (final item in s.items) {
        topCounts[item.title] = (topCounts[item.title] ?? 0) + item.qty;
      }
    }
    final topItems = topCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return AppShell(
      title: 'Tableau de bord — Boissons',
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Text('Bonjour, ${session.user.name.split(' ').first}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.md),
          StatGrid(
            children: [
              StatCard(
                label: "CA du jour",
                value: MoneyFormatter.format(revenue),
                icon: Icons.payments_outlined,
                color: const Color(0xFF0EA5B7),
              ),
              StatCard(
                label: 'Ventes du jour',
                value: '${todaySales.length}',
                icon: Icons.receipt_long_outlined,
                color: Colors.blue,
              ),
              StatCard(
                label: 'Boissons actives',
                value: '${products.where((p) => p.active).length}',
                icon: Icons.local_drink_outlined,
                color: Colors.teal,
              ),
              StatCard(
                label: 'Stock faible',
                value: '${lowStock.length}',
                icon: Icons.warning_amber_outlined,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          if (lowStock.isNotEmpty) ...[
            Text('Alertes stock faible', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.sm),
            Card(
              child: Column(
                children: lowStock
                    .map((p) => ListTile(
                          leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                          title: Text(p.name),
                          trailing: Text('${QtyFormatter.format(p.stock)} ${p.unit} restant(s)'),
                          onTap: () => context.push('/catalog/products/${p.id}'),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
          Text('Top 5 vendus aujourd\'hui', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          topItems.isEmpty
              ? const EmptyState(icon: Icons.bar_chart_outlined, title: 'Aucune vente aujourd\'hui')
              : Card(
                  child: Column(
                    children: topItems
                        .take(5)
                        .map((e) => ListTile(title: Text(e.key), trailing: Text('${QtyFormatter.plain(e.value)} vendu(s)')))
                        .toList(),
                  ),
                ),
          const SizedBox(height: AppSizes.lg),
          Text('Dernières ventes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          _RecentSales(sales: allSales.take(5).toList()),
        ],
      ),
    );
  }
}

class _RecentSales extends StatelessWidget {
  final List<SaleModel> sales;
  const _RecentSales({required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Aucune vente récente');
    }
    return Card(
      child: Column(
        children: sales
            .map((s) => ListTile(
                  title: Text('${s.id} — ${s.clientName}'),
                  subtitle: Text(DateFormatter.dateTime(s.date)),
                  trailing: Text(MoneyFormatter.format(s.total)),
                  onTap: () => context.push('/sales/${s.id}'),
                ))
            .toList(),
      ),
    );
  }
}
