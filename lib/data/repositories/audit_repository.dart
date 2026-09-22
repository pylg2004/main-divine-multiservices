import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/memory_collection.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/audit_log_model.dart';

class AuditRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;
  final _cache = MemoryCollection<AuditLogModel>();

  static const _collection = 'audit_logs';

  Future<void> log({
    required String userId,
    required String userName,
    required String action,
    String? details,
  }) async {
    final entry = AuditLogModel(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      userId: userId,
      userName: userName,
      action: action,
      details: details,
    );
    _cache.put(entry.id, entry);
    unawaited(_sync.pushDoc(_collection, entry.id, {
      'timestamp': entry.timestamp,
      'userId': entry.userId,
      'userName': entry.userName,
      'action': entry.action,
      'details': entry.details,
    }));
  }

  List<AuditLogModel> all() {
    final list = _cache.all;
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Supprime tout le journal d'audit (Firestore + cache) — utilisé par la
  /// réinitialisation des données depuis Paramètres.
  Future<void> deleteAll() async {
    final ids = _cache.all.map((e) => e.id).toList();
    for (final id in ids) {
      await _sync.deleteDoc(_collection, id);
    }
    _cache.replaceAll({});
  }

  /// Récupère le journal d'audit depuis Firestore (seule base de données)
  /// et remplace le cache en mémoire. À appeler au démarrage/après
  /// connexion — si Firestore est injoignable, le cache reste tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    final map = <String, AuditLogModel>{
      for (final data in docs)
        data['id'] as String: AuditLogModel(
          id: data['id'] as String,
          timestamp: data['timestamp'] as DateTime? ?? DateTime.now(),
          userId: data['userId'] as String? ?? '',
          userName: data['userName'] as String? ?? '',
          action: data['action'] as String? ?? '',
          details: data['details'] as String?,
        ),
    };
    _cache.replaceAll(map);
  }
}
