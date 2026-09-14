import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../models/enums.dart';
import '../models/product_model.dart';

class ProductRepository {
  final _uuid = const Uuid();

  List<ProductModel> all({bool activeOnly = false}) {
    final list = HiveDatasource.products.values
        .where((p) => !activeOnly || p.active)
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<ProductModel> byCategory(ProductCategory category) {
    return all(activeOnly: true).where((p) => p.category == category).toList();
  }

  ProductModel? byId(String id) => HiveDatasource.products.get(id);

  Future<ProductModel> create({
    required String name,
    required ProductCategory category,
    required double price,
    required String unit,
    int stock = 0,
    String? color,
  }) async {
    final product = ProductModel(
      id: _uuid.v4(),
      name: name.trim(),
      category: category,
      price: price,
      unit: unit.trim(),
      stock: stock,
      color: color?.trim(),
      createdAt: DateTime.now(),
    );
    await HiveDatasource.products.put(product.id, product);
    return product;
  }

  Future<void> update(
    ProductModel product, {
    String? name,
    ProductCategory? category,
    double? price,
    String? unit,
    int? stock,
    String? color,
    bool? active,
  }) async {
    if (name != null) product.name = name.trim();
    if (category != null) product.category = category;
    if (price != null) product.price = price;
    if (unit != null) product.unit = unit.trim();
    if (stock != null) product.stock = stock;
    if (color != null) product.color = color.trim();
    if (active != null) product.active = active;
    await product.save();
  }

  Future<void> adjustStock(String productId, int delta) async {
    final product = byId(productId);
    if (product == null) return;
    product.stock += delta;
    await product.save();
  }

  Future<void> delete(String id) async {
    await HiveDatasource.products.delete(id);
  }
}
