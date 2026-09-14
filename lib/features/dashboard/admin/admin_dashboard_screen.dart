import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/enums.dart';
import '../../../shared/permissions/workstation.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../auth/session_notifier.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final session = ref.watch(sessionProvider)!;
    final today = DateFormatter.startOfDay(DateTime.now());
    final weekStart = DateFormatter.startOfWeek(DateTime.now());
    final monthStart = DateFormatter.startOfMonth(DateTime.now());

    final allSales = ref.watch(saleRepositoryProvider).all().where((s) => s.status == SaleStatus.complete).toList();
    final todaySales = allSales.where((s) => !s.date.isBefore(today)).toList();
    final weekSales = allSales.where((s) => !s.date.isBefore(weekStart)).toList();
    final monthSales = allSales.where((s) => !s.date.isBefore(monthStart)).toList();

    final revenueToday = todaySales.fold<double>(0, (sum, s) => sum + s.total);
    final revenueWeek = weekSales.fold<double>(0, (sum, s) => sum + s.total);
    final revenueMonth = monthSales.fold<double>(0, (sum, s) => sum + s.total);

    var posToday = 0.0;
    var beautyToday = 0.0;
    for (final s in todaySales) {
      final split = s.revenueSplit();
      posToday += split.product;
      beautyToday += split.beauty;
    }

    final last7 = List.generate(7, (i) => DateFormatter.startOfDay(DateTime.now().subtract(Duration(days: 6 - i))));

    return AppShell(
      title: 'Tableau de bord — Administration',
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
                label: 'CA aujourd\'hui',
                value: MoneyFormatter.format(revenueToday),
                icon: Icons.today_outlined,
                color: Colors.blue,
              ),
              StatCard(
                label: 'CA cette semaine',
                value: MoneyFormatter.format(revenueWeek),
                icon: Icons.date_range_outlined,
                color: Colors.indigo,
              ),
              StatCard(
                label: 'CA ce mois',
                value: MoneyFormatter.format(revenueMonth),
                icon: Icons.calendar_month_outlined,
                color: Colors.teal,
              ),
              StatCard(
                label: 'POS aujourd\'hui',
                value: MoneyFormatter.format(posToday),
                icon: Icons.storefront_outlined,
                color: const Color(0xFF0F5A42),
              ),
              StatCard(
                label: 'Beauté aujourd\'hui',
                value: MoneyFormatter.format(beautyToday),
                icon: Icons.spa_outlined,
                color: const Color(0xFFD4788F),
              ),
              StatCard(
                label: 'Ventes aujourd\'hui',
                value: '${todaySales.length}',
                icon: Icons.receipt_long_outlined,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Text('CA des 7 derniers jours', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= last7.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(DateFormatter.dayMonth(last7[i]), style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: [
                      for (var i = 0; i < last7.length; i++)
                        () {
                          final dayEnd = last7[i].add(const Duration(days: 1));
                          final daySales =
                              allSales.where((s) => !s.date.isBefore(last7[i]) && s.date.isBefore(dayEnd));
                          var posDay = 0.0;
                          var beautyDay = 0.0;
                          for (final s in daySales) {
                            final split = s.revenueSplit();
                            posDay += split.product;
                            beautyDay += split.beauty;
                          }
                          return BarChartGroupData(x: i, barRods: [
                            BarChartRodData(toY: posDay, color: const Color(0xFF0F5A42), width: 8),
                            BarChartRodData(toY: beautyDay, color: const Color(0xFFD4788F), width: 8),
                          ]);
                        }(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text('Dernières ventes (tous postes)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          allSales.isEmpty
              ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Aucune vente récente')
              : Card(
                  child: Column(
                    children: allSales
                        .take(6)
                        .map((s) => ListTile(
                              leading: Icon(s.workstation.icon, color: s.workstation.color),
                              title: Text('${s.id} — ${s.clientName}'),
                              subtitle: Text('${DateFormatter.dateTime(s.date)} · ${s.sellerName}'),
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
