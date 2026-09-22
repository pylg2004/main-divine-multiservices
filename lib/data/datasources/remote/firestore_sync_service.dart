import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../firebase_options.dart';

/// Passerelle vers Firestore — la seule base de données de l'app (voir
/// data/datasources/local/memory_collection.dart pour le cache en mémoire,
/// non persistant, que chaque repository reconstruit à partir d'ici).
///
/// Toutes les opérations réseau sont protégées par un try/catch interne :
/// si Firestore est injoignable ou mal configuré, elles échouent en
/// silence (avec un `debugPrint`) plutôt que de faire planter l'app — les
/// écrans se retrouvent alors avec des listes vides/obsolètes tant que la
/// connexion n'est pas rétablie (aucune persistance locale au-delà de la
/// session en cours).
class FirestoreSyncService {
  FirestoreSyncService._();

  static final FirestoreSyncService instance = FirestoreSyncService._();

  bool _ready = false;

  /// true si Firebase a pu être initialisé (config valide, réseau OK au
  /// démarrage).
  bool get enabled => _ready;

  /// N'authentifie plus de compte technique partagé : l'app exige désormais
  /// que chaque utilisateur se connecte avec son propre compte Firebase
  /// Auth (voir AuthRepository.login) — cette session sert ensuite
  /// d'identité pour toutes les opérations Firestore (règles de sécurité :
  /// `allow read, write: if request.auth != null;`). Avant login, Firestore
  /// est donc injoignable par design — aucune donnée n'est disponible tant
  /// que l'utilisateur ne s'est pas connecté.
  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // Persistance hors-ligne : Firestore garde un cache local et
      // resynchronise automatiquement au retour du réseau.
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
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

  /// Comme [pushDoc], mais relance l'exception au lieu de l'avaler — utilisé
  /// pour les écritures qui doivent réellement échouer si Firestore est
  /// injoignable (ex: enregistrer une vente, voir [requireActiveConnection]).
  Future<void> pushDocOrThrow(String collection, String id, Map<String, dynamic> data) async {
    if (!_ready) throw StateError('Firestore non initialisé');
    await FirebaseFirestore.instance.collection(collection).doc(id).set(_encode(data));
  }

  /// Vérifie qu'une connexion internet réellement active existe (pas juste
  /// "Firestore configuré") en forçant une lecture serveur (`Source.server`
  /// contourne le cache local que Firestore maintient pour le mode
  /// hors-ligne — sans ça, cet appel pourrait réussir même sans réseau).
  /// Lève [NetworkException] si aucune connexion n'est disponible — utilisé
  /// avant les opérations qui doivent exiger internet (ex: une vente).
  Future<void> requireActiveConnection({Duration timeout = const Duration(seconds: 6)}) async {
    if (!_ready) {
      throw const NetworkException('Connexion internet requise pour continuer.');
    }
    try {
      await FirebaseFirestore.instance
          .collection('_connectivity_check')
          .doc('ping')
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
    } catch (_) {
      throw const NetworkException(
        'Connexion internet requise pour continuer. Vérifiez votre réseau et réessayez.',
      );
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

  /// Comme [pullCollection], mais relance l'exception au lieu de l'avaler —
  /// réservé aux vérifications sensibles à la sécurité (ex: décider si un
  /// compte admin existe déjà avant d'autoriser la création automatique du
  /// tout premier admin) où confondre "collection vide" et "Firestore
  /// injoignable" serait dangereux.
  Future<List<Map<String, dynamic>>> pullCollectionOrThrow(
    String collection, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_ready) throw StateError('Firestore non initialisé');
    final snapshot = await FirebaseFirestore.instance.collection(collection).get().timeout(timeout);
    return [
      for (final doc in snapshot.docs) {..._decode(doc.data()), 'id': doc.id},
    ];
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
