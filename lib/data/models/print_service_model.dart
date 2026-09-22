import 'enums.dart';

class PrintServiceModel {
  String id;
  String name;
  PrintServiceCategory category;
  double price;
  String? description;
  bool active;
  DateTime createdAt;

  PrintServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.description,
    this.active = true,
    required this.createdAt,
  });
}
