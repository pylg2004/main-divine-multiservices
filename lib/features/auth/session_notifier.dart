import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'session.dart';

const _sessionDuration = Duration(hours: 12);
const _prefsUserIdKey = 'session_user_id';
const _prefsExpiryKey = 'session_expiry';

class SessionNotifier extends StateNotifier<Session?> {
  final AuthRepository _authRepository;
  SessionNotifier(this._authRepository) : super(null);

  /// Appelée une fois dans main() avant runApp, pendant que l'écran de
  /// démarrage natif est encore affiché — donc jamais de "spinner de
  /// restauration" à gérer dans le router ou les écrans.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_prefsUserIdKey);
    final expiryMillis = prefs.getInt(_prefsExpiryKey);
    if (userId != null && expiryMillis != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      final user = _authRepository.byId(userId);
      if (user != null && user.active && DateTime.now().isBefore(expiry)) {
        state = Session(user: user, loggedInAt: DateTime.now(), expiresAt: expiry);
        return;
      }
    }
    await prefs.remove(_prefsUserIdKey);
    await prefs.remove(_prefsExpiryKey);
  }

  Future<void> login(String email, String password) async {
    final user = await _authRepository.login(email, password);
    final expiry = DateTime.now().add(_sessionDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserIdKey, user.id);
    await prefs.setInt(_prefsExpiryKey, expiry.millisecondsSinceEpoch);
    state = Session(user: user, loggedInAt: DateTime.now(), expiresAt: expiry);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUserIdKey);
    await prefs.remove(_prefsExpiryKey);
    state = null;
  }

  /// Recharge l'utilisateur courant depuis Hive (ex: après modification de
  /// son propre profil) sans le déconnecter.
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
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session?>((ref) {
  return SessionNotifier(ref.watch(authRepositoryProvider));
});
