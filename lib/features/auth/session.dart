import '../../data/models/enums.dart';
import '../../data/models/user_model.dart';
import '../../shared/permissions/permission.dart';
import '../../shared/permissions/permission_service.dart';
import '../../shared/permissions/workstation.dart';

class Session {
  final UserModel user;
  final Workstation workstation;
  final DateTime loggedInAt;
  final DateTime expiresAt;

  Session({
    required this.user,
    required this.loggedInAt,
    required this.expiresAt,
  }) : workstation = user.role.workstation;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool can(Permission permission) => PermissionService.has(user.role, permission);
}
