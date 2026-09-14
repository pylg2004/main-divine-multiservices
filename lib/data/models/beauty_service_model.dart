import 'package:hive/hive.dart';

import 'enums.dart';

part 'beauty_service_model.g.dart';

@HiveType(typeId: 2)
class BeautyServiceModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  BeautyServiceCategory category;
  @HiveField(3)
  double price;
  @HiveField(4)
  int durationMinutes;
  @HiveField(5)
  String? description;
  @HiveField(6)
  bool active;
  @HiveField(7)
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
