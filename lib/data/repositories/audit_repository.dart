import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../models/audit_log_model.dart';

class AuditRepository {
  final _uuid = const Uuid();

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
  }

  List<AuditLogModel> all() {
    final list = HiveDatasource.auditLogs.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}
