import 'package:hive/hive.dart';

import 'enums.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String id;
  /// Identifiant de connexion choisi et géré par l'admin — un simple nom
  /// d'utilisateur, pas une adresse email (le personnel n'en a pas toujours).
  @HiveField(1)
  String username;
  @HiveField(2)
  String name;
  @HiveField(3)
  UserRole role;
  @HiveField(4)
  String? phone;
  @HiveField(5)
  bool active;
  @HiveField(6)
  DateTime createdAt;
  @HiveField(7)
  String passwordHash;
  @HiveField(8)
  String salt;

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
  });
}
