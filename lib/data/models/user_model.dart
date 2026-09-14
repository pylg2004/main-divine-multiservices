import 'package:hive/hive.dart';

import 'enums.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String email;
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
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.active = true,
    required this.createdAt,
    required this.passwordHash,
    required this.salt,
  });
}
