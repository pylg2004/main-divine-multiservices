class AuditLogModel {
  String id;
  DateTime timestamp;
  String userId;
  String userName;
  String action;
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
