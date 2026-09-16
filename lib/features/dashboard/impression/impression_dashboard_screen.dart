import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/enums.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../auth/session_notifier.dart';
import '../../catalog/print_services/print_services_list_screen.dart';

class ImpressionDashboardScreen extends ConsumerWidget {
  const ImpressionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final session = ref.watch(sessionProvider)!;
    final today = DateFormatter.startOfDay(DateTime.now());

    final allSales = ref.watch(saleRepositoryProvider).byWorkstation(Workstation.impression);
    final todaySales = allSales.where((s) => !s.date.isBefore(today) && s.status == SaleStatus.complete).toList();
    final revenue = todaySales.fold<double>(0, (sum, s) => sum + s.total);
    final services = ref.watch(printServicesListProvider);

    final topCounts = <String, double>{};
    for (final s in todaySales) {
      for (final item in s.items) {
        topCounts[item.title] = (topCounts[item.title] ?? 0) + item.qty;
      }
    }
    final topServices = topCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return AppShell(
      title: 'Tableau de bord — Impression',
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Text('Bonjour, ${session.user.name.split(' ').first}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.md),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSizes.sm,
            mainAxisSpacing: AppSizes.sm,
            childAspectRatio: 1.4,
            children: [
              StatCard(
                label: "CA du jour",
                value: MoneyFormatter.format(revenue),
                icon: Icons.payments_outlined,
                color: const Color(0xFFE08A2E),
              ),
              StatCard(
                label: 'Commandes du jour',
                value:
                    '${todaySales.fold<double>(0, (sum, s) => sum + s.items.fold<double>(0, (n, i) => n + i.qty)).round()}',
                icon: Icons.local_printshop_outlined,
                color: Colors.deepOrange,
              ),
              StatCard(
                label: 'Services actifs',
                value: '${services.where((s) => s.active).length}',
                icon: Icons.checklist_outlined,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Text('Top 5 services vendus aujourd\'hui', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          topServices.isEmpty
              ? const EmptyState(icon: Icons.bar_chart_outlined, title: 'Aucune vente aujourd\'hui')
              : Card(
                  child: Column(
                    children: topServices
                        .take(5)
                        .map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value.toInt()} vendu(s)')))
                        .toList(),
                  ),
                ),
          const SizedBox(height: AppSizes.lg),
          Text('Dernières ventes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          allSales.isEmpty
              ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Aucune vente récente')
              : Card(
                  child: Column(
                    children: allSales
                        .take(5)
                        .map((s) => ListTile(
                              title: Text('${s.id} — ${s.clientName}'),
                              subtitle: Text(DateFormatter.dateTime(s.date)),
                              trailing: Text(MoneyFormatter.format(s.total)),
                              onTap: () => context.push('/sales/${s.id}'),
                            ))
                        .toList(),
                  ),
                ),
        ],
      ),
    );
  }
}
