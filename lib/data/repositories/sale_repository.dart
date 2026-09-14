import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../models/enums.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';

class SaleRepository {
  final _uuid = const Uuid();

  List<SaleModel> all() {
    final list = HiveDatasource.sales.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<SaleModel> byWorkstation(Workstation workstation) {
    return all().where((s) => s.workstation == workstation).toList();
  }

  List<SaleModel> byUser(String userId) {
    return all().where((s) => s.sellerId == userId).toList();
  }

  List<SaleModel> inRange(DateTime start, DateTime end) {
    return all()
        .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
        .toList();
  }

  SaleModel? byId(String id) => HiveDatasource.sales.get(id);

  String _nextSaleNumber() {
    final count = HiveDatasource.sales.length + 1;
    return 'VTE-${count.toString().padLeft(4, '0')}';
  }

  Future<SaleModel> create({
    required String sellerId,
    required String sellerName,
    required String sellerRole,
    required Workstation workstation,
    String? clientId,
    String clientName = 'Client anonyme',
    String clientPhone = '',
    required List<SaleItemModel> items,
    double discount = 0,
    required PaymentMethod paymentMethod,
    int loyaltyPointsEarned = 0,
  }) async {
    var id = _nextSaleNumber();
    while (HiveDatasource.sales.containsKey(id)) {
      id = '$id-${_uuid.v4().substring(0, 4)}';
    }
    final sale = SaleModel(
      id: id,
      date: DateTime.now(),
      sellerId: sellerId,
      sellerName: sellerName,
      sellerRole: sellerRole,
      workstation: workstation,
      clientId: clientId,
      clientName: clientName,
      clientPhone: clientPhone,
      items: items,
      discount: discount,
      paymentMethod: paymentMethod,
      loyaltyPointsEarned: loyaltyPointsEarned,
      createdAt: DateTime.now(),
    );
    await HiveDatasource.sales.put(sale.id, sale);
    return sale;
  }

  Future<void> cancel(String id) async {
    final sale = byId(id);
    if (sale == null) return;
    sale.status = SaleStatus.annulee;
    await sale.save();
  }

  Future<void> delete(String id) async {
    await HiveDatasource.sales.delete(id);
  }
}
