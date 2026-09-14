import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../data/models/enums.dart';
import '../../features/auth/session_notifier.dart';
import '../permissions/permission.dart';
import '../permissions/permission_service.dart';
import '../permissions/workstation.dart';
import 'confirm_dialog.dart';

/// `location.startsWith(route)` alone would make '/sale' match '/sales/...'
/// (string prefix), mis-highlighting the "Caisse" nav item while viewing
/// Ventes. Require an exact match or a '/'-bounded sub-path instead.
bool _matchesRoute(String location, String route) {
  return location == route || location.startsWith('$route/');
}

class _NavItem {
  final String route;
  final String label;
  final IconData icon;
  final Permission? permission;
  const _NavItem(this.route, this.label, this.icon, [this.permission]);
}

const _navByWorkstation = <Workstation, List<_NavItem>>{
  Workstation.pos: [
    _NavItem('/dashboard/pos', 'Tableau de bord', Icons.dashboard_outlined),
    _NavItem('/sale', 'Caisse', Icons.point_of_sale_outlined),
    _NavItem('/catalog/products', 'Produits', Icons.inventory_2_outlined),
    _NavItem('/clients', 'Clients', Icons.people_outline),
    _NavItem('/sales', 'Ventes', Icons.receipt_long_outlined),
    _NavItem('/profile', 'Profil', Icons.person_outline),
  ],
  Workstation.beauty: [
    _NavItem('/dashboard/beauty', 'Tableau de bord', Icons.dashboard_outlined),
    _NavItem('/sale', 'Caisse', Icons.point_of_sale_outlined),
    _NavItem('/catalog/beauty-services', 'Services', Icons.spa_outlined),
    _NavItem('/clients', 'Clients', Icons.people_outline),
    _NavItem('/sales', 'Ventes', Icons.receipt_long_outlined),
    _NavItem('/profile', 'Profil', Icons.person_outline),
  ],
  Workstation.admin: [
    _NavItem('/dashboard/admin', 'Tableau de bord', Icons.dashboard_outlined),
    _NavItem('/sale', 'Caisse', Icons.point_of_sale_outlined),
    _NavItem('/catalog/products', 'Produits', Icons.inventory_2_outlined),
    _NavItem('/catalog/beauty-services', 'Services beauté', Icons.spa_outlined),
    _NavItem('/clients', 'Clients', Icons.people_outline),
    _NavItem('/sales', 'Ventes', Icons.receipt_long_outlined),
    _NavItem('/reports', 'Rapports', Icons.bar_chart_outlined, Permission.reportsViewPos),
    _NavItem('/users', 'Utilisateurs', Icons.manage_accounts_outlined, Permission.usersManage),
    _NavItem('/printer-settings', 'Imprimante', Icons.print_outlined, Permission.printerSettingsManage),
    _NavItem('/settings', 'Paramètres', Icons.settings_outlined, Permission.settingsManage),
    _NavItem('/audit', 'Audit', Icons.history_outlined, Permission.auditView),
    _NavItem('/profile', 'Profil', Icons.person_outline),
  ],
};

/// Coquille commune à tous les écrans authentifiés : barre latérale/inférieure
/// adaptée au poste (spec §5 — "la sidebar n'affiche QUE les menus autorisés
/// pour ce poste"), en-tête colorée par poste, déconnexion.
class AppShell extends ConsumerWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const AppShell({super.key, required this.title, required this.child, this.actions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null) return child;

    final workstation = session.workstation;
    final items = _navByWorkstation[workstation]!
        .where((i) => i.permission == null || PermissionService.has(session.user.role, i.permission!))
        .toList();

    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = items.indexWhere((i) => _matchesRoute(location, i.route));

    final wide = MediaQuery.sizeOf(context).width >= AppSizes.tabletBreakpoint;

    final body = Row(
      children: [
        if (wide)
          NavigationRail(
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (i) => context.go(items[i].route),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              child: Icon(workstation.icon, color: workstation.color, size: 28),
            ),
            destinations: items
                .map((i) => NavigationRailDestination(
                      icon: Icon(i.icon),
                      label: Text(i.label, textAlign: TextAlign.center),
                    ))
                .toList(),
          ),
        if (wide) const VerticalDivider(width: 1),
        Expanded(
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
              backgroundColor: workstation.color,
              foregroundColor: Colors.white,
              actions: [
                ...?actions,
                Padding(
                  padding: const EdgeInsets.only(right: AppSizes.sm),
                  child: Center(
                    child: Chip(
                      label: Text(session.user.name, style: const TextStyle(fontSize: 12)),
                      avatar: const Icon(Icons.person, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Déconnexion',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Déconnexion',
                      message: 'Voulez-vous vraiment vous déconnecter ?',
                    );
                    if (ok) await ref.read(sessionProvider.notifier).logout();
                  },
                ),
              ],
            ),
            body: SafeArea(child: child),
            bottomNavigationBar: wide ? null : _buildBottomNav(context, items, location),
          ),
        ),
      ],
    );

    return body;
  }

  Widget _buildBottomNav(BuildContext context, List<_NavItem> items, String location) {
    final bottomItems = items.take(5).toList();
    var bottomIndex = bottomItems.indexWhere((i) => _matchesRoute(location, i.route));
    if (bottomIndex < 0) bottomIndex = 0;
    return NavigationBar(
      selectedIndex: bottomIndex,
      onDestinationSelected: (i) => context.go(bottomItems[i].route),
      destinations: bottomItems
          .map((i) => NavigationDestination(icon: Icon(i.icon), label: i.label))
          .toList(),
    );
  }
}
