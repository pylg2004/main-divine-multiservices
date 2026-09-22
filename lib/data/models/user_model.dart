import 'enums.dart';

class UserModel {
  String id;
  /// Identifiant de connexion choisi et géré par l'admin — un simple nom
  /// d'utilisateur, pas une adresse email (le personnel n'en a pas toujours).
  String username;
  String name;
  UserRole role;
  String? phone;
  bool active;
  DateTime createdAt;
  String passwordHash;
  String salt;
  /// Départements (postes) auxquels ce compte a accès, en plus de celui par
  /// défaut de son rôle — permet d'assigner un vendeur à plusieurs rayons
  /// (ex: Papeterie + Boissons) via des cases à cocher dans le formulaire
  /// utilisateur. Vide = comportement historique (un seul poste, dérivé du
  /// rôle via [WorkstationExtension.workstation]).
  List<Workstation> departments;
  /// Identifiant de connexion Firebase Auth — obligatoire depuis le passage
  /// à l'authentification cloud (voir AuthRepository.login).
  String email;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.phone,
    this.active = true,
    required this.createdAt,
    required this.passwordHash,
    required this.salt,
    List<Workstation>? departments,
    this.email = '',
  }) : departments = departments ?? [];
}
