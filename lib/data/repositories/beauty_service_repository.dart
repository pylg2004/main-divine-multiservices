import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../models/beauty_service_model.dart';
import '../models/enums.dart';

class BeautyServiceRepository {
  final _uuid = const Uuid();

  List<BeautyServiceModel> all({bool activeOnly = false}) {
    final list = HiveDatasource.beautyServices.values
        .where((s) => !activeOnly || s.active)
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<BeautyServiceModel> byCategory(BeautyServiceCategory category) {
    return all(activeOnly: true)
        .where((s) => s.category == category)
        .toList();
  }

  BeautyServiceModel? byId(String id) => HiveDatasource.beautyServices.get(id);

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
    await HiveDatasource.beautyServices.put(service.id, service);
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
    await service.save();
  }

  Future<void> delete(String id) async {
    await HiveDatasource.beautyServices.delete(id);
  }
}
