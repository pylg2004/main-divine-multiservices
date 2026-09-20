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
  /// Décidé par l'admin/gestionnaire : si `false`, ce produit n'est jamais
  /// concerné par la remise quantité automatique (10 % dès 3 achetés),
  /// quelle que soit la quantité vendue.
  @HiveField(9)
  bool discountEligible;

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
    this.discountEligible = true,
  });
}
