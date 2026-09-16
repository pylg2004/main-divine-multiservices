import 'package:firedart/firedart.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/firebase_config.dart';

/// Passerelle générique vers Firestore, utilisée par les repositories comme
/// base de données prioritaire (voir [FirebaseConfig]).
///
/// Toutes les opérations réseau sont protégées par un try/catch interne :
/// si Firestore est injoignable ou mal configuré, elles échouent en
/// silence (avec un `debugPrint`) plutôt que de faire planter l'app — le
/// cache local (Hive) reste alors la seule source de données, comme avant
/// l'ajout de Firebase.
class FirestoreSyncService {
  FirestoreSyncService._();

  static final FirestoreSyncService instance = FirestoreSyncService._();

  bool _ready = false;

  /// true si un projet Firebase est configuré ET que l'initialisation a
  /// réussi (connexion réseau/identifiants valides au démarrage).
  bool get enabled => _ready;

  Future<void> init() async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      if (FirebaseConfig.hasAuth) {
        FirebaseAuth.initialize(FirebaseConfig.apiKey, VolatileStore());
        await FirebaseAuth.instance.signIn(
          FirebaseConfig.syncEmail,
          FirebaseConfig.syncPassword,
        );
      }
      Firestore.initialize(FirebaseConfig.projectId);
      _ready = true;
    } catch (e) {
      debugPrint('[FirestoreSyncService] Initialisation impossible: $e');
      _ready = false;
    }
  }

  Future<void> pushDoc(String collection, String id, Map<String, dynamic> data) async {
    if (!_ready) return;
    try {
      await Firestore.instance.collection(collection).document(id).set(data);
    } catch (e) {
      debugPrint('[FirestoreSyncService] Échec envoi $collection/$id: $e');
    }
  }

  Future<void> deleteDoc(String collection, String id) async {
    if (!_ready) return;
    try {
      await Firestore.instance.collection(collection).document(id).delete();
    } catch (e) {
      debugPrint('[FirestoreSyncService] Échec suppression $collection/$id: $e');
    }
  }

  /// Récupère tous les documents d'une collection Firestore. Chaque élément
  /// contient les champs du document plus une clé `id`. Retourne une liste
  /// vide si Firestore est désactivé, injoignable ou vide — jamais
  /// d'exception.
  Future<List<Map<String, dynamic>>> pullCollection(
    String collection, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_ready) return [];
    try {
      final results = <Map<String, dynamic>>[];
      var token = '';
      do {
        final page = await Firestore.instance
            .collection(collection)
            .get(nextPageToken: token)
            .timeout(timeout);
        for (final doc in page) {
          results.add({...doc.map, 'id': doc.id});
        }
        token = page.nextPageToken;
      } while (token.isNotEmpty);
      return results;
    } catch (e) {
      debugPrint('[FirestoreSyncService] Échec lecture $collection: $e');
      return [];
    }
  }
}
