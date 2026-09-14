import '../../data/models/user_model.dart';
import '../../data/repositories/audit_repository.dart';

/// Enveloppe fine autour d'[AuditRepository] pour que les features n'aient
/// jamais à construire elles-mêmes un AuditLogModel — un seul point d'appel
/// pour toute action auditée (connexion, vente, gestion utilisateurs...).
class AuditService {
  final AuditRepository _repository;
  AuditService(this._repository);

  Future<void> log(UserModel actor, String action, {String? details}) {
    return _repository.log(
      userId: actor.id,
      userName: actor.name,
      action: action,
      details: details,
    );
  }
}
