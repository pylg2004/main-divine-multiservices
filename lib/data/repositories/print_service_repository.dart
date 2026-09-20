import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/enums.dart';
import '../models/print_service_model.dart';

class PrintServiceRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;

  static const _collection = 'print_services';

  List<PrintServiceModel> all({bool activeOnly = false}) {
    final list = HiveDatasource.printServices.values
        .where((s) => !activeOnly || s.active)
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<PrintServiceModel> byCategory(PrintServiceCategory category) {
    return all(activeOnly: true).where((s) => s.category == category).toList();
  }

  PrintServiceModel? byId(String id) => HiveDatasource.printServices.get(id);

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
    await HiveDatasource.printServices.put(service.id, service);
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
    await service.save();
    unawaited(_pushToFirestore(service));
  }

  Future<void> delete(String id) async {
    await HiveDatasource.printServices.delete(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  /// Récupère les services d'impression depuis Firestore (source de
  /// vérité) et remplace le cache local. À appeler au démarrage — si
  /// Firestore n'est pas configuré/injoignable, le cache local existant
  /// est conservé tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    for (final data in docs) {
      await HiveDatasource.printServices.put(data['id'] as String, _fromFirestore(data));
    }
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
