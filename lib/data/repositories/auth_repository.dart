import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../datasources/local/hive_datasource.dart';
import '../models/enums.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _uuid = const Uuid();

  static String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() => const Uuid().v4();

  bool verifyPassword(UserModel user, String password) {
    return _hash(password, user.salt) == user.passwordHash;
  }

  bool get hasAnyUser => HiveDatasource.users.isNotEmpty;

  UserModel? findByUsername(String username) {
    final normalized = username.trim().toLowerCase();
    try {
      return HiveDatasource.users.values
          .firstWhere((u) => u.username.toLowerCase() == normalized);
    } catch (_) {
      return null;
    }
  }

  Future<UserModel> login(String username, String password) async {
    final user = findByUsername(username);
    if (user == null) {
      throw const AuthException("Nom d'utilisateur ou mot de passe incorrect");
    }
    if (!user.active) {
      throw const AuthException('Ce compte a été désactivé');
    }
    if (!verifyPassword(user, password)) {
      throw const AuthException("Nom d'utilisateur ou mot de passe incorrect");
    }
    return user;
  }

  Future<UserModel> createUser({
    required String username,
    required String name,
    required UserRole role,
    String? phone,
    required String password,
    bool active = true,
  }) async {
    if (findByUsername(username) != null) {
      throw const ValidationException('Un utilisateur avec ce nom d\'utilisateur existe déjà');
    }
    final salt = generateSalt();
    final user = UserModel(
      id: _uuid.v4(),
      username: username.trim(),
      name: name.trim(),
      role: role,
      phone: phone?.trim(),
      active: active,
      createdAt: DateTime.now(),
      passwordHash: _hash(password, salt),
      salt: salt,
    );
    await HiveDatasource.users.put(user.id, user);
    return user;
  }

  Future<void> updateUser(
    UserModel user, {
    String? name,
    String? phone,
    UserRole? role,
    bool? active,
    String? newPassword,
  }) async {
    if (name != null) user.name = name.trim();
    if (phone != null) user.phone = phone.trim();
    if (role != null) user.role = role;
    if (active != null) user.active = active;
    if (newPassword != null && newPassword.isNotEmpty) {
      final salt = generateSalt();
      user.salt = salt;
      user.passwordHash = _hash(newPassword, salt);
    }
    await user.save();
  }

  Future<void> deleteUser(String id) async {
    await HiveDatasource.users.delete(id);
  }

  List<UserModel> allUsers() {
    final list = HiveDatasource.users.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  UserModel? byId(String id) => HiveDatasource.users.get(id);
}
