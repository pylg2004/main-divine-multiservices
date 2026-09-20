import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/firebase_config.dart';
import '../../../firebase_options.dart';

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

  /// true si Firebase a pu être initialisé (config valide, réseau OK au
  /// démarrage).
  bool get enabled => _ready;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // Persistance hors-ligne : Firestore garde un cache local et
      // resynchronise automatiquement au retour du réseau.
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      if (FirebaseConfig.hasAuth) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: FirebaseConfig.syncEmail,
          password: FirebaseConfig.syncPassword,
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('[FirestoreSyncService] Initialisation impossible: $e');
      _ready = false;
    }
  }

  Future<void> pushDoc(String collection, String id, Map<String, dynamic> data) async {
    if (!_ready) return;
    try {
      await FirebaseFirestore.instance.collection(collection).doc(id).set(_encode(data));
    } catch (e) {
      debugPrint('[FirestoreSyncService] Échec envoi $collection/$id: $e');
    }
  }

  Future<void> deleteDoc(String collection, String id) async {
    if (!_ready) return;
    try {
      await FirebaseFirestore.instance.collection(collection).doc(id).delete();
    } catch (e) {
      debugPrint('[FirestoreSyncService] Échec suppression $collection/$id: $e');
    }
  }

  /// Récupère un document unique. Retourne `null` si Firestore est
  /// désactivé, injoignable, ou si le document n'existe pas.
  Future<Map<String, dynamic>?> pullDoc(
    String collection,
    String id, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_ready) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(id).get().timeout(timeout);
      if (!doc.exists) return null;
      final data = doc.data();
      return data == null ? null : _decode(data);
    } catch (e) {
      debugPrint('[FirestoreSyncService] Échec lecture $collection/$id: $e');
      return null;
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
      final snapshot = await FirebaseFirestore.instance.collection(collection).get().timeout(timeout);
      return [
        for (final doc in snapshot.docs) {..._decode(doc.data()), 'id': doc.id},
      ];
    } catch (e) {
      debugPrint('[FirestoreSyncService] Échec lecture $collection: $e');
      return [];
    }
  }

  /// Convertit les [DateTime] en [Timestamp] Firestore avant envoi (le SDK
  /// n'accepte pas les DateTime bruts).
  Map<String, dynamic> _encode(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is DateTime) return MapEntry(key, Timestamp.fromDate(value));
      return MapEntry(key, value);
    });
  }

  /// Convertit les [Timestamp] Firestore en [DateTime] à la lecture.
  Map<String, dynamic> _decode(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) return MapEntry(key, value.toDate());
      return MapEntry(key, value);
    });
  }
}
