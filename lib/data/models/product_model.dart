import 'enums.dart';

class ProductModel {
  String id;
  String name;
  ProductCategory category;
  double price;
  String unit;
  double stock;
  String? color;
  bool active;
  DateTime createdAt;
  /// Décidé par l'admin/gestionnaire : si `false`, ce produit n'est jamais
  /// concerné par la remise quantité automatique (10 % dès 3 achetés),
  /// quelle que soit la quantité vendue.
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
