import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../datasources/local/memory_collection.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/enums.dart';
import '../models/user_model.dart';

/// Gère les comptes utilisateurs. Depuis le passage à l'authentification
/// cloud, la connexion (spec utilisateur) exige Firebase Auth + une
/// connexion internet active — il n'y a plus de vérification de mot de
/// passe purement locale. `passwordHash`/`salt` restent dans [UserModel]
/// pour compatibilité mais ne sont plus utilisés pour authentifier qui que
/// ce soit.
class AuthRepository {
  final _sync = FirestoreSyncService.instance;
  final _cache = MemoryCollection<UserModel>();

  static const _collection = 'users';

  static String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() => const Uuid().v4();

  bool get hasAnyUser => _cache.isNotEmpty;

  UserModel? findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    try {
      return _cache.all.firstWhere((u) => u.email.toLowerCase() == normalized);
    } catch (_) {
      return null;
    }
  }

  UserModel? byId(String id) => _cache.byId(id);

  /// Connecte l'utilisateur via Firebase Auth (email + mot de passe) —
  /// exige une connexion internet active. Si aucun compte n'existe encore
  /// nulle part (tout premier lancement), l'email/mot de passe saisis
  /// deviennent automatiquement le compte Super Administrateur fondateur.
  Future<UserModel> login(String email, String password) async {
    final normalizedEmail = email.trim();
    UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' && await _canBootstrapFirstAdmin()) {
        return _bootstrapFirstAdmin(normalizedEmail, password);
      }
      throw AuthException(_authErrorMessage(e));
    }

    final uid = credential.user!.uid;
    final user = await _syncUserAfterSignIn(uid: uid, email: normalizedEmail, password: password);
    if (!user.active) {
      await FirebaseAuth.instance.signOut();
      throw const AuthException('Ce compte a été désactivé');
    }
    return user;
  }

  /// true seulement si Firestore est joignable ET ne contient encore aucun
  /// utilisateur — en cas de doute (réseau, permissions), on refuse le
  /// bootstrap plutôt que de risquer de créer un second "premier admin"
  /// pendant que le vrai compte existe déjà mais est temporairement
  /// injoignable.
  Future<bool> _canBootstrapFirstAdmin() async {
    try {
      final docs = await _sync.pullCollectionOrThrow(_collection);
      return docs.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<UserModel> _bootstrapFirstAdmin(String email, String password) async {
    UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
    return _createFounderProfile(uid: credential.user!.uid, email: email, password: password);
  }

  Future<UserModel> _createFounderProfile({
    required String uid,
    required String email,
    required String password,
  }) async {
    final salt = generateSalt();
    final user = UserModel(
      id: uid,
      username: email.split('@').first,
      name: email.split('@').first,
      role: UserRole.superAdmin,
      active: true,
      createdAt: DateTime.now(),
      passwordHash: _hash(password, salt),
      salt: salt,
      email: email,
    );
    _cache.put(user.id, user);
    await _pushToFirestore(user);
    return user;
  }

  /// Après un signIn réussi, récupère le profil applicatif (rôle,
  /// départements...) correspondant depuis Firestore et met à jour le
  /// cache local.
  ///
  /// Cas particulier : un compte Firebase Auth peut exister sans profil
  /// Firestore associé (ex: un compte créé manuellement dans la console, ou
  /// l'ancien compte technique de synchronisation utilisé avant le passage
  /// à l'authentification par utilisateur) — si Firestore ne contient
  /// encore AUCUN utilisateur, ce compte devient alors le Super Admin
  /// fondateur (même logique que [_bootstrapFirstAdmin], sans recréer le
  /// compte Auth puisqu'il est déjà authentifié). Sinon, la connexion est
  /// refusée : un compte authentifié sans profil alors que d'autres
  /// comptes existent déjà n'est jamais légitime.
  Future<UserModel> _syncUserAfterSignIn({
    required String uid,
    required String email,
    required String password,
  }) async {
    List<Map<String, dynamic>> docs;
    try {
      docs = await _sync.pullCollectionOrThrow(_collection);
    } catch (_) {
      final local = byId(uid) ?? findByEmail(email);
      if (local != null) return local;
      await FirebaseAuth.instance.signOut();
      throw const AuthException('Connexion internet requise pour terminer la connexion. Réessayez.');
    }

    Map<String, dynamic>? match;
    for (final d in docs) {
      if (d['id'] == uid || (d['email'] as String?)?.toLowerCase() == email.toLowerCase()) {
        match = d;
        break;
      }
    }
    if (match != null) {
      final user = _fromFirestore(match);
      _cache.put(user.id, user);
      return user;
    }

    final local = byId(uid) ?? findByEmail(email);
    if (local != null) return local;

    if (docs.isEmpty) {
      return _createFounderProfile(uid: uid, email: email, password: password);
    }

    await FirebaseAuth.instance.signOut();
    throw const AuthException(
      "Compte authentifié mais introuvable dans l'application. Contactez un administrateur.",
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      case 'invalid-email':
        return 'Adresse email invalide';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'network-request-failed':
        return 'Connexion internet requise pour se connecter. Vérifiez votre réseau.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      default:
        return 'Connexion impossible : ${e.message ?? e.code}';
    }
  }

  /// Crée un nouvel utilisateur (compte Firebase Auth + profil applicatif).
  /// Utilise une instance Firebase secondaire éphémère pour que la création
  /// du nouveau compte ne déconnecte pas l'administrateur courant (limite
  /// connue du SDK client : `createUserWithEmailAndPassword` connecte
  /// normalement l'utilisateur nouvellement créé sur l'instance appelante).
  Future<UserModel> createUser({
    required String email,
    required String name,
    required UserRole role,
    String? phone,
    required String password,
    bool active = true,
    List<Workstation> departments = const [],
  }) async {
    final normalizedEmail = email.trim();
    if (findByEmail(normalizedEmail) != null) {
      throw const ValidationException('Un utilisateur avec cet email existe déjà');
    }

    final secondaryApp = await Firebase.initializeApp(
      name: 'userCreation-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    String uid;
    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      uid = credential.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }

    final salt = generateSalt();
    final user = UserModel(
      id: uid,
      username: normalizedEmail.split('@').first,
      name: name.trim(),
      role: role,
      phone: phone?.trim(),
      active: active,
      createdAt: DateTime.now(),
      passwordHash: _hash(password, salt),
      salt: salt,
      departments: departments,
      email: normalizedEmail,
    );
    _cache.put(user.id, user);
    unawaited(_pushToFirestore(user));
    return user;
  }

  Future<void> updateUser(
    UserModel user, {
    String? name,
    String? phone,
    UserRole? role,
    bool? active,
    List<Workstation>? departments,
  }) async {
    if (name != null) user.name = name.trim();
    if (phone != null) user.phone = phone.trim();
    if (role != null) user.role = role;
    if (active != null) user.active = active;
    if (departments != null) user.departments = departments;
    unawaited(_pushToFirestore(user));
  }

  /// Change le mot de passe de l'utilisateur *actuellement connecté*
  /// (le SDK Firebase Auth client ne permet pas de changer le mot de passe
  /// d'un autre compte — voir [sendPasswordReset] pour ce cas).
  Future<void> updateOwnPassword(String newPassword) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      throw const AuthException('Aucune session active.');
    }
    try {
      await current.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthException('Reconnectez-vous puis réessayez de changer votre mot de passe.');
      }
      throw AuthException(_authErrorMessage(e));
    }
  }

  /// Envoie un email de réinitialisation de mot de passe — c'est le seul
  /// moyen, depuis le SDK client, de permettre à un administrateur de
  /// "changer" le mot de passe d'un compte qui n'est pas le sien.
  Future<void> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  Future<void> deleteUser(String id) async {
    _cache.remove(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  List<UserModel> allUsers() {
    final list = _cache.all;
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Récupère les comptes utilisateurs depuis Firestore (seule base de
  /// données) et remplace le cache en mémoire. Appelée après connexion —
  /// avant login, Firestore est injoignable (aucune session Firebase
  /// Auth), donc cet appel échoue silencieusement et n'a aucun effet.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    final map = <String, UserModel>{
      for (final data in docs) data['id'] as String: _fromFirestore(data),
    };
    _cache.replaceAll(map);
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
      'departments': user.departments.map((w) => w.name).toList(),
      'email': user.email,
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
      departments: (data['departments'] as List?)
              ?.map((e) => Workstation.values.firstWhere((w) => w.name == e, orElse: () => Workstation.pos))
              .toList() ??
          const [],
      email: data['email'] as String? ?? '',
    );
  }
}
