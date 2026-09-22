import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/memory_collection.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/enums.dart';
import '../models/product_model.dart';

class ProductRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;
  final _cache = MemoryCollection<ProductModel>();

  static const _collection = 'products';

  List<ProductModel> all({bool activeOnly = false}) {
    final list = _cache.all.where((p) => !activeOnly || p.active).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<ProductModel> byCategory(ProductCategory category) {
    return all(activeOnly: true).where((p) => p.category == category).toList();
  }

  ProductModel? byId(String id) => _cache.byId(id);

  Future<ProductModel> create({
    required String name,
    required ProductCategory category,
    required double price,
    required String unit,
    double stock = 0,
    String? color,
    bool discountEligible = true,
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
      discountEligible: discountEligible,
    );
    _cache.put(product.id, product);
    unawaited(_pushToFirestore(product));
    return product;
  }

  Future<void> update(
    ProductModel product, {
    String? name,
    ProductCategory? category,
    double? price,
    String? unit,
    double? stock,
    String? color,
    bool? active,
    bool? discountEligible,
  }) async {
    if (name != null) product.name = name.trim();
    if (category != null) product.category = category;
    if (price != null) product.price = price;
    if (unit != null) product.unit = unit.trim();
    if (stock != null) product.stock = stock;
    if (color != null) product.color = color.trim();
    if (active != null) product.active = active;
    if (discountEligible != null) product.discountEligible = discountEligible;
    unawaited(_pushToFirestore(product));
  }

  Future<void> adjustStock(String productId, double delta) async {
    final product = byId(productId);
    if (product == null) return;
    product.stock += delta;
    unawaited(_pushToFirestore(product));
  }

  Future<void> delete(String id) async {
    _cache.remove(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  /// Supprime tous les produits (Firestore + cache) — utilisé par la
  /// réinitialisation des données depuis Paramètres.
  Future<void> deleteAll() async {
    final ids = _cache.all.map((p) => p.id).toList();
    for (final id in ids) {
      await _sync.deleteDoc(_collection, id);
    }
    _cache.replaceAll({});
  }

  /// Récupère le catalogue produits depuis Firestore (seule base de
  /// données) et remplace le cache en mémoire. À appeler au démarrage/après
  /// connexion — si Firestore est injoignable, le cache reste tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    final map = <String, ProductModel>{
      for (final data in docs) data['id'] as String: _fromFirestore(data),
    };
    _cache.replaceAll(map);
  }

  Future<void> _pushToFirestore(ProductModel product) {
    return _sync.pushDoc(_collection, product.id, {
      'name': product.name,
      'category': product.category.name,
      'price': product.price,
      'unit': product.unit,
      'stock': product.stock,
      'color': product.color,
      'active': product.active,
      'createdAt': product.createdAt,
      'discountEligible': product.discountEligible,
    });
  }

  ProductModel _fromFirestore(Map<String, dynamic> data) {
    return ProductModel(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      category: ProductCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => ProductCategory.papeterie,
      ),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String? ?? 'unité',
      stock: (data['stock'] as num?)?.toDouble() ?? 0,
      color: data['color'] as String?,
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
      discountEligible: data['discountEligible'] as bool? ?? true,
    );
  }
}
