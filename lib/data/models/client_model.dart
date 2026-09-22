class ClientModel {
  String id;
  String fullName;
  String phone;
  String? email;
  DateTime? birthDate;
  String? notes;
  int loyaltyPoints;
  double totalSpent;
  DateTime createdAt;
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
