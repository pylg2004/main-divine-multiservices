import 'enums.dart';

class BeautyServiceModel {
  String id;
  String name;
  BeautyServiceCategory category;
  double price;
  int durationMinutes;
  String? description;
  bool active;
  DateTime createdAt;

  BeautyServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.durationMinutes = 30,
    this.description,
    this.active = true,
    required this.createdAt,
  });

  Duration get duration => Duration(minutes: durationMinutes);
}
