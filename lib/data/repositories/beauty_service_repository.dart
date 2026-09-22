import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/memory_collection.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/beauty_service_model.dart';
import '../models/enums.dart';

class BeautyServiceRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;
  final _cache = MemoryCollection<BeautyServiceModel>();

  static const _collection = 'beauty_services';

  List<BeautyServiceModel> all({bool activeOnly = false}) {
    final list = _cache.all.where((s) => !activeOnly || s.active).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<BeautyServiceModel> byCategory(BeautyServiceCategory category) {
    return all(activeOnly: true)
        .where((s) => s.category == category)
        .toList();
  }

  BeautyServiceModel? byId(String id) => _cache.byId(id);

  Future<BeautyServiceModel> create({
    required String name,
    required BeautyServiceCategory category,
    required double price,
    int durationMinutes = 30,
    String? description,
  }) async {
    final service = BeautyServiceModel(
      id: _uuid.v4(),
      name: name.trim(),
      category: category,
      price: price,
      durationMinutes: durationMinutes,
      description: description?.trim(),
      createdAt: DateTime.now(),
    );
    _cache.put(service.id, service);
    unawaited(_pushToFirestore(service));
    return service;
  }

  Future<void> update(
    BeautyServiceModel service, {
    String? name,
    BeautyServiceCategory? category,
    double? price,
    int? durationMinutes,
    String? description,
    bool? active,
  }) async {
    if (name != null) service.name = name.trim();
    if (category != null) service.category = category;
    if (price != null) service.price = price;
    if (durationMinutes != null) service.durationMinutes = durationMinutes;
    if (description != null) service.description = description.trim();
    if (active != null) service.active = active;
    unawaited(_pushToFirestore(service));
  }

  Future<void> delete(String id) async {
    _cache.remove(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  /// Supprime tous les services (Firestore + cache) — utilisé par la
  /// réinitialisation des données depuis Paramètres.
  Future<void> deleteAll() async {
    final ids = _cache.all.map((s) => s.id).toList();
    for (final id in ids) {
      await _sync.deleteDoc(_collection, id);
    }
    _cache.replaceAll({});
  }

  /// Récupère les services beauté depuis Firestore (seule base de données)
  /// et remplace le cache en mémoire. À appeler au démarrage/après
  /// connexion — si Firestore est injoignable, le cache reste tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    final map = <String, BeautyServiceModel>{
      for (final data in docs) data['id'] as String: _fromFirestore(data),
    };
    _cache.replaceAll(map);
  }

  Future<void> _pushToFirestore(BeautyServiceModel service) {
    return _sync.pushDoc(_collection, service.id, {
      'name': service.name,
      'category': service.category.name,
      'price': service.price,
      'durationMinutes': service.durationMinutes,
      'description': service.description,
      'active': service.active,
      'createdAt': service.createdAt,
    });
  }

  BeautyServiceModel _fromFirestore(Map<String, dynamic> data) {
    return BeautyServiceModel(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      category: BeautyServiceCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => BeautyServiceCategory.autre,
      ),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      description: data['description'] as String?,
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
    );
  }
}
