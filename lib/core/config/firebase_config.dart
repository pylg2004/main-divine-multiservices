/// Configuration de connexion à Firebase (Firestore).
///
/// Firestore est la base de données PRIORITAIRE de l'app (voir
/// `FirestoreSyncService`) : au démarrage, l'app récupère les données
/// depuis Firestore et les copie dans le cache local (Hive) ; chaque
/// création/modification locale est ensuite renvoyée vers Firestore. Hive
/// reste utilisé comme cache hors-ligne — si Firestore est injoignable,
/// l'app continue de fonctionner avec les dernières données synchronisées.
///
/// ─── Pour activer la synchronisation ───
/// Ces valeurs sont lues à la compilation via `--dart-define-from-file`
/// (jamais commitées en clair dans le code) :
///
/// 1. Copiez `firebase.env.example.json` vers `firebase.env.json` (déjà
///    ignoré par git) et renseignez `FIREBASE_PROJECT_ID` avec l'ID de
///    votre projet (Console Firebase → ⚙ Paramètres du projet → ID du
///    projet).
/// 2. Si vos règles de sécurité Firestore autorisent la lecture/écriture
///    sans authentification (mode test), c'est tout.
/// 3. Si vos règles exigent une authentification, créez un compte dédié
///    (Authentication → Utilisateurs → Ajouter un utilisateur) et
///    renseignez `FIREBASE_API_KEY` (Paramètres du projet → Général → Clé
///    API Web), `FIREBASE_SYNC_EMAIL` et `FIREBASE_SYNC_PASSWORD`.
/// 4. Lancez/compilez avec :
///    flutter run --dart-define-from-file=firebase.env.json
///
/// Tant que `FIREBASE_PROJECT_ID` est vide, la synchronisation reste
/// désactivée et l'app fonctionne comme avant (100% locale, Hive seul).
class FirebaseConfig {
  FirebaseConfig._();

  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String syncEmail = String.fromEnvironment('FIREBASE_SYNC_EMAIL');
  static const String syncPassword = String.fromEnvironment('FIREBASE_SYNC_PASSWORD');

  static bool get isConfigured => projectId.isNotEmpty;
  static bool get hasAuth => apiKey.isNotEmpty && syncEmail.isNotEmpty && syncPassword.isNotEmpty;
}
