import 'package:hive/hive.dart';

part 'client_model.g.dart';

@HiveType(typeId: 3)
class ClientModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String fullName;
  @HiveField(2)
  String phone;
  @HiveField(3)
  String? email;
  @HiveField(4)
  DateTime? birthDate;
  @HiveField(5)
  String? notes;
  @HiveField(6)
  int loyaltyPoints;
  @HiveField(7)
  double totalSpent;
  @HiveField(8)
  DateTime createdAt;
  @HiveField(9)
  DateTime? lastVisit;

  ClientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.birthDate,
    this.notes,
    this.loyaltyPoints = 0,
    this.totalSpent = 0,
    required this.createdAt,
    this.lastVisit,
  });
}
