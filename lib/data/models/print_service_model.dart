import 'package:hive/hive.dart';

import 'enums.dart';

part 'print_service_model.g.dart';

@HiveType(typeId: 9)
class PrintServiceModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  PrintServiceCategory category;
  @HiveField(3)
  double price;
  @HiveField(4)
  String? description;
  @HiveField(5)
  bool active;
  @HiveField(6)
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
