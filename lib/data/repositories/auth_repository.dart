import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../datasources/local/hive_datasource.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/enums.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;

  static const _collection = 'users';

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
    unawaited(_pushToFirestore(user));
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
    unawaited(_pushToFirestore(user));
  }

  Future<void> deleteUser(String id) async {
    await HiveDatasource.users.delete(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  List<UserModel> allUsers() {
    final list = HiveDatasource.users.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  UserModel? byId(String id) => HiveDatasource.users.get(id);

  /// Récupère les comptes utilisateurs depuis Firestore (source de vérité)
  /// et remplace le cache local. À appeler au démarrage — si Firestore
  /// n'est pas configuré/injoignable, le cache local existant est
  /// conservé tel quel.
  ///
  /// Attention : ceci synchronise `passwordHash`/`salt` vers Firestore.
  /// Le hash est salé (SHA-256) donc pas trivialement réversible, mais la
  /// collection `users` doit rester protégée par des règles de sécurité
  /// Firestore restrictives (pas de lecture publique) — voir
  /// FirebaseConfig.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    for (final data in docs) {
      await HiveDatasource.users.put(data['id'] as String, _fromFirestore(data));
    }
  }

  Future<void> _pushToFirestore(UserModel user) {
    return _sync.pushDoc(_collection, user.id, {
      'username': user.username,
      'name': user.name,
      'role': user.role.name,
      'phone': user.phone,
      'active': user.active,
      'createdAt': user.createdAt,
      'passwordHash': user.passwordHash,
      'salt': user.salt,
    });
  }

  UserModel _fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] as String,
      username: data['username'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.vendeur,
      ),
      phone: data['phone'] as String?,
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
      passwordHash: data['passwordHash'] as String? ?? '',
      salt: data['salt'] as String? ?? '',
    );
  }
}
