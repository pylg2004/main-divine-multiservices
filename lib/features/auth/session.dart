import '../../data/models/enums.dart';
import '../../data/models/user_model.dart';
import '../../shared/permissions/permission.dart';
import '../../shared/permissions/permission_service.dart';
import '../../shared/permissions/workstation.dart';

class Session {
  final UserModel user;

  /// Tous les postes auxquels ce compte a accès. Vide `user.departments`
  /// (cas historique, un seul poste par compte) → l'unique poste dérivé du
  /// rôle ; sinon les départements cochés dans le formulaire utilisateur.
  final Set<Workstation> workstations;

  /// Poste "principal" (couleur de la barre d'app, tableau de bord
  /// d'accueil) — le premier de [workstations] selon [kDepartmentOrder].
  final Workstation workstation;

  final DateTime loggedInAt;
  final DateTime expiresAt;

  Session({
    required this.user,
    required this.loggedInAt,
    required this.expiresAt,
  })  : workstations = _effectiveWorkstations(user),
        workstation = kDepartmentOrder.firstWhere(
          _effectiveWorkstations(user).contains,
          orElse: () => user.role.workstation,
        );

  static Set<Workstation> _effectiveWorkstations(UserModel user) =>
      user.departments.isNotEmpty ? user.departments.toSet() : {user.role.workstation};

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool can(Permission permission) => PermissionService.has(user.role, permission);
}
