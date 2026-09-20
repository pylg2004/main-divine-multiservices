import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/enums.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';

class SaleRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;

  static const _collection = 'sales';

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
    unawaited(_pushToFirestore(sale));
    return sale;
  }

  Future<void> cancel(String id) async {
    final sale = byId(id);
    if (sale == null) return;
    sale.status = SaleStatus.annulee;
    await sale.save();
    unawaited(_pushToFirestore(sale));
  }

  Future<void> delete(String id) async {
    await HiveDatasource.sales.delete(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  /// Récupère les ventes depuis Firestore (source de vérité) et remplace
  /// le cache local. À appeler au démarrage — si Firestore n'est pas
  /// configuré/injoignable, le cache local existant est conservé tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    for (final data in docs) {
      await HiveDatasource.sales.put(data['id'] as String, _fromFirestore(data));
    }
  }

  Future<void> _pushToFirestore(SaleModel sale) {
    return _sync.pushDoc(_collection, sale.id, {
      'date': sale.date,
      'sellerId': sale.sellerId,
      'sellerName': sale.sellerName,
      'sellerRole': sale.sellerRole,
      'workstation': sale.workstation.name,
      'clientId': sale.clientId,
      'clientName': sale.clientName,
      'clientPhone': sale.clientPhone,
      'items': sale.items.map(_itemToMap).toList(),
      'discount': sale.discount,
      'paymentMethod': sale.paymentMethod.name,
      'status': sale.status.name,
      'loyaltyPointsEarned': sale.loyaltyPointsEarned,
      'createdAt': sale.createdAt,
    });
  }

  SaleModel _fromFirestore(Map<String, dynamic> data) {
    return SaleModel(
      id: data['id'] as String,
      date: data['date'] as DateTime? ?? DateTime.now(),
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      sellerRole: data['sellerRole'] as String? ?? '',
      workstation: Workstation.values.firstWhere(
        (w) => w.name == data['workstation'],
        orElse: () => Workstation.pos,
      ),
      clientId: data['clientId'] as String?,
      clientName: data['clientName'] as String? ?? 'Client anonyme',
      clientPhone: data['clientPhone'] as String? ?? '',
      items: ((data['items'] as List?) ?? [])
          .map((e) => _itemFromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == data['paymentMethod'],
        orElse: () => PaymentMethod.especes,
      ),
      status: SaleStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SaleStatus.complete,
      ),
      loyaltyPointsEarned: (data['loyaltyPointsEarned'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _itemToMap(SaleItemModel item) => {
        'id': item.id,
        'type': item.type.name,
        'referenceId': item.referenceId,
        'title': item.title,
        'category': item.category,
        'unit': item.unit,
        'color': item.color,
        'qty': item.qty,
        'unitPrice': item.unitPrice,
        'discountEligible': item.discountEligible,
      };

  SaleItemModel _itemFromMap(Map<String, dynamic> map) => SaleItemModel(
        id: map['id'] as String? ?? '',
        type: SaleItemType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => SaleItemType.product,
        ),
        referenceId: map['referenceId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        category: map['category'] as String?,
        unit: map['unit'] as String? ?? 'unité',
        color: map['color'] as String?,
        qty: (map['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        discountEligible: map['discountEligible'] as bool? ?? true,
      );
}
