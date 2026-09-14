import 'package:hive/hive.dart';

part 'audit_log_model.g.dart';

@HiveType(typeId: 6)
class AuditLogModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  DateTime timestamp;
  @HiveField(2)
  String userId;
  @HiveField(3)
  String userName;
  @HiveField(4)
  String action;
  @HiveField(5)
  String? details;

  AuditLogModel({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.action,
    this.details,
  });
}
