/// Configuration de connexion à Firebase (Firestore).
///
/// Firestore est la base de données PRIORITAIRE de l'app (voir
/// `FirestoreSyncService`) : au démarrage, l'app récupère les données
/// depuis Firestore et les copie dans le cache local (Hive) ; chaque
/// création/modification locale est ensuite renvoyée vers Firestore. Hive
/// reste utilisé comme cache hors-ligne — si Firestore est injoignable,
/// l'app continue de fonctionner avec les dernières données synchronisées.
///
/// Le projet Firebase lui-même (project id, clés API par plateforme) vient
/// de `lib/firebase_options.dart`, généré par `flutterfire configure` et
/// commité normalement (ces clés ne sont pas secrètes).
///
/// Si vos règles de sécurité Firestore autorisent la lecture/écriture sans
/// authentification (mode test), rien d'autre à configurer. Si elles
/// exigent une authentification, créez un compte dédié à la synchronisation
/// (Firebase Console → Authentication → Utilisateurs → Ajouter un
/// utilisateur) et fournissez ses identifiants à la compilation, sans les
/// commiter :
///
/// 1. Copiez `firebase.env.example.json` vers `firebase.env.json` (déjà
///    ignoré par git) et renseignez `FIREBASE_SYNC_EMAIL` /
///    `FIREBASE_SYNC_PASSWORD`.
/// 2. Lancez/compilez avec :
///    flutter run --dart-define-from-file=firebase.env.json
class FirebaseConfig {
  FirebaseConfig._();

  static const String syncEmail = String.fromEnvironment('FIREBASE_SYNC_EMAIL');
  static const String syncPassword = String.fromEnvironment('FIREBASE_SYNC_PASSWORD');

  static bool get hasAuth => syncEmail.isNotEmpty && syncPassword.isNotEmpty;
}
