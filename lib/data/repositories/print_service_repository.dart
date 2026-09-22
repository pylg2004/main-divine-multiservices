import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/memory_collection.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/enums.dart';
import '../models/print_service_model.dart';

class PrintServiceRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;
  final _cache = MemoryCollection<PrintServiceModel>();

  static const _collection = 'print_services';

  List<PrintServiceModel> all({bool activeOnly = false}) {
    final list = _cache.all.where((s) => !activeOnly || s.active).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<PrintServiceModel> byCategory(PrintServiceCategory category) {
    return all(activeOnly: true).where((s) => s.category == category).toList();
  }

  PrintServiceModel? byId(String id) => _cache.byId(id);

  Future<PrintServiceModel> create({
    required String name,
    required PrintServiceCategory category,
    required double price,
    String? description,
  }) async {
    final service = PrintServiceModel(
      id: _uuid.v4(),
      name: name.trim(),
      category: category,
      price: price,
      description: description?.trim(),
      createdAt: DateTime.now(),
    );
    _cache.put(service.id, service);
    unawaited(_pushToFirestore(service));
    return service;
  }

  Future<void> update(
    PrintServiceModel service, {
    String? name,
    PrintServiceCategory? category,
    double? price,
    String? description,
    bool? active,
  }) async {
    if (name != null) service.name = name.trim();
    if (category != null) service.category = category;
    if (price != null) service.price = price;
    if (description != null) service.description = description.trim();
    if (active != null) service.active = active;
    unawaited(_pushToFirestore(service));
  }

  Future<void> delete(String id) async {
    _cache.remove(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  /// Récupère les services d'impression depuis Firestore (seule base de
  /// données) et remplace le cache en mémoire. À appeler au démarrage/après
  /// connexion — si Firestore est injoignable, le cache reste tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    final map = <String, PrintServiceModel>{
      for (final data in docs) data['id'] as String: _fromFirestore(data),
    };
    _cache.replaceAll(map);
  }

  Future<void> _pushToFirestore(PrintServiceModel service) {
    return _sync.pushDoc(_collection, service.id, {
      'name': service.name,
      'category': service.category.name,
      'price': service.price,
      'description': service.description,
      'active': service.active,
      'createdAt': service.createdAt,
    });
  }

  PrintServiceModel _fromFirestore(Map<String, dynamic> data) {
    return PrintServiceModel(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      category: PrintServiceCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => PrintServiceCategory.autre,
      ),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      description: data['description'] as String?,
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
    );
  }
}
