import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'session.dart';

const _sessionDuration = Duration(hours: 12);
const _prefsExpiryKey = 'session_expiry';

class SessionNotifier extends StateNotifier<Session?> {
  final AuthRepository _authRepository;
  final Ref _ref;
  SessionNotifier(this._authRepository, this._ref) : super(null);

  /// Appelée une fois dans main() avant runApp, pendant que l'écran de
  /// démarrage natif est encore affiché.
  ///
  /// Depuis que Firestore est la seule base de données (plus de cache
  /// local persistant), restaurer une session exige désormais une
  /// connexion internet : on s'appuie sur la session Firebase Auth déjà
  /// persistée nativement par le SDK (`currentUser`), puis on rapatrie le
  /// profil applicatif depuis Firestore. Sans réseau au démarrage, la
  /// restauration échoue silencieusement et l'utilisateur revoit l'écran
  /// de connexion.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMillis = prefs.getInt(_prefsExpiryKey);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || expiryMillis == null) {
      await prefs.remove(_prefsExpiryKey);
      return;
    }
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    if (!DateTime.now().isBefore(expiry)) {
      await prefs.remove(_prefsExpiryKey);
      return;
    }
    await _pullAllFromFirestore();
    final user = _authRepository.byId(firebaseUser.uid) ??
        _authRepository.findByEmail(firebaseUser.email ?? '');
    if (user != null && user.active) {
      state = Session(user: user, loggedInAt: DateTime.now(), expiresAt: expiry);
    }
  }

  /// Connexion : exige Firebase Auth + internet actif (voir
  /// AuthRepository.login). Une fois connecté, rapatrie toutes les données
  /// métier (produits, ventes, clients...) avant de considérer la connexion
  /// terminée, pour éviter un dashboard vide/obsolète à l'arrivée.
  Future<void> login(String email, String password) async {
    final user = await _authRepository.login(email, password);
    final expiry = DateTime.now().add(_sessionDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsExpiryKey, expiry.millisecondsSinceEpoch);
    state = Session(user: user, loggedInAt: DateTime.now(), expiresAt: expiry);
    await _pullAllFromFirestore();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsExpiryKey);
    await FirebaseAuth.instance.signOut();
    state = null;
  }

  /// Recharge l'utilisateur courant depuis le cache (ex: après modification
  /// de son propre profil) sans le déconnecter.
  void refreshUser() {
    final current = state;
    if (current == null) return;
    final fresh = _authRepository.byId(current.user.id);
    if (fresh == null) {
      state = null;
      return;
    }
    state = Session(user: fresh, loggedInAt: current.loggedInAt, expiresAt: current.expiresAt);
  }

  /// Chaque appel échoue silencieusement en interne (voir
  /// FirestoreSyncService) : sans connexion, les caches en mémoire restent
  /// simplement vides ou inchangés plutôt que de faire planter l'app.
  Future<void> _pullAllFromFirestore() async {
    await Future.wait([
      _authRepository.pullFromFirestore(),
      _ref.read(productRepositoryProvider).pullFromFirestore(),
      _ref.read(clientRepositoryProvider).pullFromFirestore(),
      _ref.read(beautyServiceRepositoryProvider).pullFromFirestore(),
      _ref.read(printServiceRepositoryProvider).pullFromFirestore(),
      _ref.read(saleRepositoryProvider).pullFromFirestore(),
      _ref.read(settingsRepositoryProvider).pullFromFirestore(),
      _ref.read(auditRepositoryProvider).pullFromFirestore(),
    ]);
    _ref.read(dataRevisionProvider.notifier).state++;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session?>((ref) {
  return SessionNotifier(ref.watch(authRepositoryProvider), ref);
});
