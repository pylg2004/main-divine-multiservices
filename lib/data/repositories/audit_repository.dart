import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/audit_log_model.dart';

class AuditRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;

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
    await HiveDatasource.auditLogs.put(entry.id, entry);
    unawaited(_sync.pushDoc(_collection, entry.id, {
      'timestamp': entry.timestamp,
      'userId': entry.userId,
      'userName': entry.userName,
      'action': entry.action,
      'details': entry.details,
    }));
  }

  List<AuditLogModel> all() {
    final list = HiveDatasource.auditLogs.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Récupère le journal d'audit depuis Firestore (source de vérité) et
  /// remplace le cache local. À appeler au démarrage — si Firestore n'est
  /// pas configuré/injoignable, le cache local existant est conservé tel
  /// quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    for (final data in docs) {
      await HiveDatasource.auditLogs.put(
        data['id'] as String,
        AuditLogModel(
          id: data['id'] as String,
          timestamp: data['timestamp'] as DateTime? ?? DateTime.now(),
          userId: data['userId'] as String? ?? '',
          userName: data['userName'] as String? ?? '',
          action: data['action'] as String? ?? '',
          details: data['details'] as String?,
        ),
      );
    }
  }
}
