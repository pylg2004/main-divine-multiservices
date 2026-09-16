import 'package:hive/hive.dart';

import 'enums.dart';

part 'product_model.g.dart';

@HiveType(typeId: 1)
class ProductModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  ProductCategory category;
  @HiveField(3)
  double price;
  @HiveField(4)
  String unit;
  @HiveField(5)
  double stock;
  @HiveField(6)
  String? color;
  @HiveField(7)
  bool active;
  @HiveField(8)
  DateTime createdAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    this.stock = 0,
    this.color,
    this.active = true,
    required this.createdAt,
  });
}
