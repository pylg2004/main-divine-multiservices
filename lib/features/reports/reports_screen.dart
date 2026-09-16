import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/providers.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/qty_formatter.dart';
import '../../data/models/enums.dart';
import '../../shared/permissions/permission.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/stat_card.dart';
import '../auth/session_notifier.dart';

enum ReportPeriod { day, week, month, year, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.day;
  Workstation? _workstationFilter;
  DateTimeRange? _customRange;

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    switch (_period) {
      case ReportPeriod.day:
        return (DateFormatter.startOfDay(now), DateFormatter.endOfDay(now));
      case ReportPeriod.week:
        return (DateFormatter.startOfWeek(now), DateFormatter.endOfDay(now));
      case ReportPeriod.month:
        return (DateFormatter.startOfMonth(now), DateFormatter.endOfDay(now));
      case ReportPeriod.year:
        return (DateFormatter.startOfYear(now), DateFormatter.endOfDay(now));
      case ReportPeriod.custom:
        if (_customRange == null) return (DateFormatter.startOfDay(now), DateFormatter.endOfDay(now));
        return (DateFormatter.startOfDay(_customRange!.start), DateFormatter.endOfDay(_customRange!.end));
    }
  }

  String _periodLabel() {
    final (start, end) = _range();
    switch (_period) {
      case ReportPeriod.day:
        return 'Journée du ${DateFormatter.date(start)}';
      case ReportPeriod.week:
        return 'Semaine du ${DateFormatter.date(start)} au ${DateFormatter.date(end)}';
      case ReportPeriod.month:
        return DateFormatter.monthYear(start);
      case ReportPeriod.year:
        return 'Année ${start.year}';
      case ReportPeriod.custom:
        return '${DateFormatter.date(start)} au ${DateFormatter.date(end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final session = ref.watch(sessionProvider)!;
    // Le personnel sans vue globale (vendeur, caissier, beautician,
    // imprimeur) n'a que reportsViewOwn : son "Mon rapport" est
    // automatiquement borné à ses propres ventes, sans filtre de poste
    // (il n'en a qu'un seul de toute façon).
    final ownReportOnly = !session.can(Permission.reportsViewPos);

    final (start, end) = _range();
    var allSales = ref.watch(saleRepositoryProvider).inRange(start, end).where((s) => s.status == SaleStatus.complete);
    if (ownReportOnly) {
      allSales = allSales.where((s) => s.sellerId == session.user.id);
    }
    final sales = _workstationFilter == null || ownReportOnly
        ? allSales.toList()
        : allSales.where((s) => s.workstation == _workstationFilter).toList();

    var posRevenue = 0.0;
    var beautyRevenue = 0.0;
    var printRevenue = 0.0;
    for (final s in sales) {
      final split = s.revenueByType();
      posRevenue += split[SaleItemType.product] ?? 0;
      beautyRevenue += split[SaleItemType.beautyService] ?? 0;
      printRevenue += split[SaleItemType.printService] ?? 0;
    }
    final totalRevenue = posRevenue + beautyRevenue + printRevenue;
    final averageTicket = sales.isEmpty ? 0 : totalRevenue / sales.length;
    final uniqueClients = sales.map((s) => s.clientId).whereType<String>().toSet().length;

    final paymentTotals = <PaymentMethod, double>{
      for (final m in PaymentMethod.values) m: sales.where((s) => s.paymentMethod == m).fold(0, (sum, s) => sum + s.total),
    };

    final itemCounts = <String, double>{};
    for (final s in sales) {
      for (final item in s.items) {
        itemCounts[item.title] = (itemCounts[item.title] ?? 0) + item.qty;
      }
    }
    final topItems = itemCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final clientTotals = <String, double>{};
    final clientNames = <String, String>{};
    for (final s in sales) {
      if (s.clientId == null) continue;
      clientTotals[s.clientId!] = (clientTotals[s.clientId!] ?? 0) + s.total;
      clientNames[s.clientId!] = s.clientName;
    }
    final topClients = clientTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final userTotals = <String, double>{};
    final userSaleCounts = <String, int>{};
    for (final s in sales) {
      userTotals[s.sellerName] = (userTotals[s.sellerName] ?? 0) + s.total;
      userSaleCounts[s.sellerName] = (userSaleCounts[s.sellerName] ?? 0) + 1;
    }

    return AppShell(
      title: ownReportOnly ? 'Mon rapport' : 'Rapports',
      actions: [
        PermissionGate(
          permission: Permission.reportsPrint,
          child: IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final company = ref.read(settingsRepositoryProvider).company;
              try {
                final bytes = ownReportOnly
                    ? await ref.read(thermalPrinterServiceProvider).buildPersonalReport(
                          company: company,
                          periodLabel: _periodLabel(),
                          sellerName: session.user.name,
                          salesCount: sales.length,
                          totalRevenue: totalRevenue,
                          topItems: topItems.take(5).map((e) => (title: e.key, qty: e.value)).toList(),
                          paymentsByMethod: paymentTotals,
                        )
                    : await ref.read(thermalPrinterServiceProvider).buildDailyReport(
                          company: company,
                          periodLabel: _periodLabel(),
                          posSalesCount:
                              sales.where((s) => s.items.any((i) => i.type == SaleItemType.product)).length,
                          posRevenue: posRevenue,
                          beautySalesCount:
                              sales.where((s) => s.items.any((i) => i.type == SaleItemType.beautyService)).length,
                          beautyRevenue: beautyRevenue,
                          printSalesCount:
                              sales.where((s) => s.items.any((i) => i.type == SaleItemType.printService)).length,
                          printRevenue: printRevenue,
                          paymentsByMethod: paymentTotals,
                          editedBy: session.user.name,
                        );
                await ref.read(thermalPrinterServiceProvider).printBytes(bytes);
                ToastService.success('Rapport imprimé');
              } catch (e) {
                ToastService.error(e.toString());
              }
            },
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in ReportPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_periodChipLabel(p)),
                      selected: _period == p,
                      onSelected: (_) async {
                        if (p == ReportPeriod.custom) {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (range != null) setState(() => _customRange = range);
                        }
                        setState(() => _period = p);
                      },
                    ),
                  ),
                if (!ownReportOnly) ...[
                  const SizedBox(width: 16),
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
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(_periodLabel(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSizes.sm,
            mainAxisSpacing: AppSizes.sm,
            childAspectRatio: 1.4,
            children: [
              StatCard(label: 'CA total', value: MoneyFormatter.format(totalRevenue), icon: Icons.payments_outlined, color: Colors.blue),
              StatCard(label: 'CA produits', value: MoneyFormatter.format(posRevenue), icon: Icons.storefront_outlined, color: const Color(0xFF0F5A42)),
              StatCard(label: 'CA services beauté', value: MoneyFormatter.format(beautyRevenue), icon: Icons.spa_outlined, color: const Color(0xFFD4788F)),
              StatCard(label: 'CA impression', value: MoneyFormatter.format(printRevenue), icon: Icons.local_printshop_outlined, color: const Color(0xFFE08A2E)),
              StatCard(label: 'Nb ventes', value: '${sales.length}', icon: Icons.receipt_long_outlined, color: Colors.purple),
              StatCard(label: 'Ticket moyen', value: MoneyFormatter.format(averageTicket), icon: Icons.confirmation_number_outlined, color: Colors.teal),
              StatCard(label: 'Clients uniques', value: '$uniqueClients', icon: Icons.people_outline, color: Colors.indigo),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          if (totalRevenue > 0) ...[
            Text('Modes de paiement', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: paymentTotals[PaymentMethod.especes] ?? 0,
                              color: Colors.green,
                              title: '',
                              radius: 50,
                            ),
                            PieChartSectionData(
                              value: paymentTotals[PaymentMethod.carte] ?? 0,
                              color: Colors.blue,
                              title: '',
                              radius: 50,
                            ),
                            PieChartSectionData(
                              value: paymentTotals[PaymentMethod.mobile] ?? 0,
                              color: Colors.orange,
                              title: '',
                              radius: 50,
                            ),
                          ],
                        )),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legend(Colors.green, 'Espèces', paymentTotals[PaymentMethod.especes] ?? 0),
                            _legend(Colors.blue, 'Carte', paymentTotals[PaymentMethod.carte] ?? 0),
                            _legend(Colors.orange, 'Mobile', paymentTotals[PaymentMethod.mobile] ?? 0),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
          Text('Top articles / services', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          Card(
            child: topItems.isEmpty
                ? const Padding(padding: EdgeInsets.all(AppSizes.md), child: Text('Aucune donnée'))
                : Column(
                    children: topItems
                        .take(10)
                        .map((e) => ListTile(title: Text(e.key), trailing: Text('${QtyFormatter.plain(e.value)} vendu(s)')))
                        .toList(),
                  ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text('Top clients', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.sm),
          Card(
            child: topClients.isEmpty
                ? const Padding(padding: EdgeInsets.all(AppSizes.md), child: Text('Aucune donnée'))
                : Column(
                    children: topClients
                        .take(10)
                        .map((e) => ListTile(
                              title: Text(clientNames[e.key] ?? '—'),
                              trailing: Text(MoneyFormatter.format(e.value)),
                            ))
                        .toList(),
                  ),
          ),
          PermissionGate(
            permission: Permission.reportsViewConsolidated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.lg),
                Text('Performance par utilisateur', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSizes.sm),
                Card(
                  child: userTotals.isEmpty
                      ? const Padding(padding: EdgeInsets.all(AppSizes.md), child: Text('Aucune donnée'))
                      : Column(
                          children: userTotals.entries
                              .map((e) => ListTile(
                                    title: Text(e.key),
                                    subtitle: Text('${userSaleCounts[e.key]} vente(s)'),
                                    trailing: Text(MoneyFormatter.format(e.value)),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text('$label: ${MoneyFormatter.format(value)}', style: const TextStyle(fontSize: 12)),
      ]),
    );
  }

  String _periodChipLabel(ReportPeriod p) {
    switch (p) {
      case ReportPeriod.day:
        return 'Jour';
      case ReportPeriod.week:
        return 'Semaine';
      case ReportPeriod.month:
        return 'Mois';
      case ReportPeriod.year:
        return 'Année';
      case ReportPeriod.custom:
        return 'Personnalisé';
    }
  }
}
