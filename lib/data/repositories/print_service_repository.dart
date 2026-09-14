import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../models/enums.dart';
import '../models/print_service_model.dart';

class PrintServiceRepository {
  final _uuid = const Uuid();

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
  }

  Future<void> delete(String id) async {
    await HiveDatasource.printServices.delete(id);
  }
}
