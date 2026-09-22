import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/enums.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/session_notifier.dart';
import '../features/cashier/sale_screen/sale_screen.dart';
import '../features/catalog/beauty_services/beauty_service_form_screen.dart';
import '../features/catalog/beauty_services/beauty_services_list_screen.dart';
import '../features/catalog/products/product_form_screen.dart';
import '../features/catalog/products/products_list_screen.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/client_form_screen.dart';
import '../features/clients/clients_list_screen.dart';
import '../features/catalog/print_services/print_service_form_screen.dart';
import '../features/catalog/print_services/print_services_list_screen.dart';
import '../features/dashboard/admin/admin_dashboard_screen.dart';
import '../features/dashboard/beauty/beauty_dashboard_screen.dart';
import '../features/dashboard/boisson/boisson_dashboard_screen.dart';
import '../features/dashboard/general/general_dashboard_screen.dart';
import '../features/dashboard/impression/impression_dashboard_screen.dart';
import '../features/dashboard/pos/pos_dashboard_screen.dart';
import '../features/printer_settings/printer_settings_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/sales/sale_detail_screen.dart';
import '../features/sales/sales_list_screen.dart';
import '../features/settings/audit_log_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/setup/setup_wizard_screen.dart';
import '../features/users/user_form_screen.dart';
import '../features/users/users_list_screen.dart';
import '../shared/permissions/permission.dart';
import '../shared/permissions/permission_service.dart';
import '../shared/permissions/workstation.dart';

/// Postes autorisés par préfixe de route. Toute route absente de cette map
/// est accessible à n'importe quel utilisateur connecté (ex: /clients,
/// /sales, /sale, /profile — communs aux 3 postes par design du spec).
const Map<String, List<Workstation>> _routeWorkstations = {
  '/dashboard/pos': [Workstation.pos],
  '/dashboard/beauty': [Workstation.beauty],
  '/dashboard/admin': [Workstation.admin],
  '/dashboard/impression': [Workstation.impression],
  '/dashboard/general': [Workstation.general],
  '/dashboard/boisson': [Workstation.boisson],
  '/catalog/products': [Workstation.pos, Workstation.admin, Workstation.general, Workstation.boisson],
  '/catalog/beauty-services': [Workstation.beauty, Workstation.admin, Workstation.general],
  '/catalog/print-services': [Workstation.impression, Workstation.admin, Workstation.general],
  '/users': [Workstation.admin],
  '/settings': [Workstation.admin],
  '/printer-settings': [Workstation.admin],
  '/audit': [Workstation.admin],
};

/// Permission(s) requise(s) par préfixe de route, au-delà du filtre par poste
/// ci-dessus (garde "action" — spec §6/§12). N'importe laquelle des
/// permissions listées suffit — /reports sert aussi bien le rapport complet
/// de l'admin (reportsViewPos) que le rapport personnel du personnel
/// (reportsViewOwn).
const Map<String, List<Permission>> _routePermissions = {
  '/reports': [Permission.reportsViewPos, Permission.reportsViewOwn],
  '/users': [Permission.usersManage],
  '/settings': [Permission.settingsManage],
  '/printer-settings': [Permission.printerSettingsManage],
  '/audit': [Permission.auditView],
};

final routerProvider = Provider<GoRouter>((ref) {
  // On ne surveille que l'identité de la session : un changement ici
  // (login/logout) reconstruit le router, ce qui est le comportement voulu
  // pour cette transition peu fréquente. L'app démarre toujours sur /login
  // — plus de wizard obligatoire au premier lancement : le tout premier
  // compte Super Admin se crée automatiquement à la première connexion
  // réussie (voir AuthRepository.login). Le wizard (/setup) reste
  // accessible manuellement pour configurer entreprise/imprimante.
  final session = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (loc == '/setup') return null;

      if (session == null) {
        return loc == '/login' ? null : '/login';
      }
      if (loc == '/login' || loc == '/dashboard' || loc == '/') {
        return session.workstation.homeRoute;
      }

      final allowedWorkstations =
          _routeWorkstations.entries.firstWhereOrNull((e) => loc.startsWith(e.key))?.value;
      if (allowedWorkstations != null && !allowedWorkstations.any(session.workstations.contains)) {
        return session.workstation.homeRoute;
      }

      final requiredPermissions =
          _routePermissions.entries.firstWhereOrNull((e) => loc.startsWith(e.key))?.value;
      if (requiredPermissions != null &&
          !requiredPermissions.any((p) => PermissionService.has(session.user.role, p))) {
        return session.workstation.homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (context, state) => const SetupWizardScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/dashboard', redirect: (context, state) => '/dashboard/pos'),
      GoRoute(path: '/dashboard/pos', builder: (context, state) => const PosDashboardScreen()),
      GoRoute(path: '/dashboard/beauty', builder: (context, state) => const BeautyDashboardScreen()),
      GoRoute(path: '/dashboard/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/dashboard/impression', builder: (context, state) => const ImpressionDashboardScreen()),
      GoRoute(path: '/dashboard/general', builder: (context, state) => const GeneralDashboardScreen()),
      GoRoute(path: '/dashboard/boisson', builder: (context, state) => const BoissonDashboardScreen()),
      GoRoute(path: '/sale', builder: (context, state) => const SaleScreen()),
      GoRoute(
        path: '/catalog/products',
        builder: (context, state) => const ProductsListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const ProductFormScreen()),
          GoRoute(path: ':id', builder: (context, state) => ProductFormScreen(productId: state.pathParameters['id'])),
        ],
      ),
      GoRoute(
        path: '/catalog/beauty-services',
        builder: (context, state) => const BeautyServicesListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const BeautyServiceFormScreen()),
          GoRoute(
            path: ':id',
            builder: (context, state) => BeautyServiceFormScreen(serviceId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/catalog/print-services',
        builder: (context, state) => const PrintServicesListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const PrintServiceFormScreen()),
          GoRoute(
            path: ':id',
            builder: (context, state) => PrintServiceFormScreen(serviceId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const SalesListScreen(),
        routes: [
          GoRoute(path: 'my-sales', builder: (context, state) => const SalesListScreen(ownOnly: true)),
          GoRoute(path: ':id', builder: (context, state) => SaleDetailScreen(saleId: state.pathParameters['id']!)),
        ],
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const ClientFormScreen()),
          GoRoute(
            path: ':id',
            builder: (context, state) => ClientDetailScreen(clientId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => ClientFormScreen(clientId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const UserFormScreen()),
          GoRoute(path: ':id', builder: (context, state) => UserFormScreen(userId: state.pathParameters['id'])),
        ],
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/printer-settings', builder: (context, state) => const PrinterSettingsScreen()),
      GoRoute(path: '/audit', builder: (context, state) => const AuditLogScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    ],
  );
});
