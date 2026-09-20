import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../data/models/enums.dart';
import '../../features/auth/session.dart';
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

/// Initiales (1 ou 2 lettres) utilisées dans l'avatar rond de la barre
/// d'app — ex. "Admin Test" -> "AT", "Rosemé" -> "R".
String _initials(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
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
    _NavItem('/reports', 'Mon rapport', Icons.bar_chart_outlined, Permission.reportsViewOwn),
    _NavItem('/profile', 'Profil', Icons.person_outline),
  ],
  Workstation.beauty: [
    _NavItem('/dashboard/beauty', 'Tableau de bord', Icons.dashboard_outlined),
    _NavItem('/sale', 'Caisse', Icons.point_of_sale_outlined),
    _NavItem('/catalog/beauty-services', 'Services', Icons.spa_outlined),
    _NavItem('/clients', 'Clients', Icons.people_outline),
    _NavItem('/sales', 'Ventes', Icons.receipt_long_outlined),
    _NavItem('/reports', 'Mon rapport', Icons.bar_chart_outlined, Permission.reportsViewOwn),
    _NavItem('/profile', 'Profil', Icons.person_outline),
  ],
  Workstation.impression: [
    _NavItem('/dashboard/impression', 'Tableau de bord', Icons.dashboard_outlined),
    _NavItem('/sale', 'Caisse', Icons.point_of_sale_outlined),
    _NavItem('/catalog/print-services', 'Services impression', Icons.local_printshop_outlined),
    _NavItem('/clients', 'Clients', Icons.people_outline),
    _NavItem('/sales', 'Ventes', Icons.receipt_long_outlined),
    _NavItem('/reports', 'Mon rapport', Icons.bar_chart_outlined, Permission.reportsViewOwn),
    _NavItem('/profile', 'Profil', Icons.person_outline),
  ],
  Workstation.general: [
    _NavItem('/dashboard/general', 'Tableau de bord', Icons.dashboard_outlined),
    _NavItem('/sale', 'Caisse', Icons.point_of_sale_outlined),
    _NavItem('/catalog/products', 'Produits', Icons.inventory_2_outlined),
    _NavItem('/catalog/beauty-services', 'Services beauté', Icons.spa_outlined),
    _NavItem('/catalog/print-services', 'Services impression', Icons.local_printshop_outlined),
    _NavItem('/clients', 'Clients', Icons.people_outline),
    _NavItem('/sales', 'Ventes', Icons.receipt_long_outlined),
    _NavItem('/reports', 'Mon rapport', Icons.bar_chart_outlined, Permission.reportsViewOwn),
    _NavItem('/profile', 'Profil', Icons.person_outline),
  ],
  Workstation.admin: [
    _NavItem('/dashboard/admin', 'Tableau de bord', Icons.dashboard_outlined),
    _NavItem('/sale', 'Caisse', Icons.point_of_sale_outlined),
    _NavItem('/catalog/products', 'Produits', Icons.inventory_2_outlined),
    _NavItem('/catalog/beauty-services', 'Services beauté', Icons.spa_outlined),
    _NavItem('/catalog/print-services', 'Services impression', Icons.local_printshop_outlined),
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

/// Coquille commune à tous les écrans authentifiés — mobile-first : un menu
/// tiroir (Drawer) sert de navigation principale sur petit écran (pas de
/// limite de nombre d'entrées, contrairement à une bottom bar) ; à partir de
/// [AppSizes.tabletBreakpoint] un NavigationRail permanent le remplace. La
/// sidebar/le tiroir n'affiche QUE les menus autorisés pour ce poste (spec §5).
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

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: workstation.color,
        foregroundColor: Colors.white,
        actions: [
          ...?actions,
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.sm),
            child: Center(
              child: Tooltip(
                message: session.user.name,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    _initials(session.user.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
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
      drawer: wide
          ? null
          : _AppDrawer(
              session: session,
              workstation: workstation,
              items: items,
              selectedIndex: selectedIndex,
            ),
      body: wide
          ? Row(
              children: [
                _WideNavRail(workstation: workstation, items: items, selectedIndex: selectedIndex),
                const VerticalDivider(width: 1),
                Expanded(child: SafeArea(child: child)),
              ],
            )
          : SafeArea(child: child),
    );

    return scaffold;
  }
}

class _WideNavRail extends StatelessWidget {
  final Workstation workstation;
  final List<_NavItem> items;
  final int selectedIndex;

  const _WideNavRail({required this.workstation, required this.items, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
        child: IntrinsicHeight(
          child: NavigationRail(
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
        ),
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final Session session;
  final Workstation workstation;
  final List<_NavItem> items;
  final int selectedIndex;

  const _AppDrawer({
    required this.session,
    required this.workstation,
    required this.items,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: workstation.color),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(workstation.icon, color: Colors.white, size: 36),
                const SizedBox(height: AppSizes.sm),
                Text(
                  session.user.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  workstation.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            ListTile(
              leading: Icon(items[i].icon),
              title: Text(items[i].label),
              selected: i == selectedIndex,
              selectedTileColor: workstation.color.withValues(alpha: 0.1),
              selectedColor: workstation.color,
              onTap: () {
                Navigator.of(context).pop();
                context.go(items[i].route);
              },
            ),
        ],
      ),
    );
  }
}
