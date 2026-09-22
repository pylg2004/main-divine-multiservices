import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../datasources/local/memory_collection.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/enums.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';
import 'product_repository.dart';

class SaleRepository {
  final ProductRepository _productRepo;
  SaleRepository(this._productRepo);

  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;
  final _cache = MemoryCollection<SaleModel>();

  static const _collection = 'sales';

  List<SaleModel> all() {
    final list = _cache.all;
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

  SaleModel? byId(String id) => _cache.byId(id);

  String _nextSaleNumber() {
    final count = _cache.length + 1;
    return 'VTE-${count.toString().padLeft(4, '0')}';
  }

  /// Enregistre une vente — exige une connexion internet active (voir
  /// FirestoreSyncService.requireActiveConnection) : une transaction
  /// financière ne doit jamais rester uniquement locale en attente de
  /// synchronisation. Si l'envoi vers Firestore échoue après l'écriture
  /// locale, celle-ci est annulée (rollback) plutôt que de laisser une
  /// vente "fantôme" non synchronisée.
  ///
  /// Refuse aussi la vente si un produit du panier dépasse le stock
  /// disponible (voir [_validateStock]) — vérifié juste avant
  /// l'enregistrement pour limiter (sans l'éliminer) le risque qu'un autre
  /// vendeur ait vendu le même produit entretemps.
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
    await _sync.requireActiveConnection();
    _validateStock(items);
    var id = _nextSaleNumber();
    while (_cache.containsKey(id)) {
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
    _cache.put(sale.id, sale);
    try {
      await _pushToFirestoreOrThrow(sale);
    } catch (_) {
      _cache.remove(sale.id);
      rethrow;
    }
    await _applyStockDelta(sale.items, reverse: false);
    return sale;
  }

  /// Vérifie que la quantité demandée pour chaque produit du panier ne
  /// dépasse pas le stock disponible — les services (beauté, impression)
  /// n'ont pas de stock et ne sont pas concernés.
  void _validateStock(List<SaleItemModel> items) {
    for (final item in items) {
      if (item.type != SaleItemType.product) continue;
      final product = _productRepo.byId(item.referenceId);
      if (product == null) continue;
      if (item.qty > product.stock) {
        throw ValidationException(
          'Stock insuffisant pour "${product.name}" : ${item.qty} demandé, '
          '${product.stock} disponible(s).',
        );
      }
    }
  }

  /// Décrémente (vente) ou réintègre (annulation) le stock des produits
  /// vendus. Les services (sans stock) sont ignorés.
  Future<void> _applyStockDelta(List<SaleItemModel> items, {required bool reverse}) async {
    for (final item in items) {
      if (item.type != SaleItemType.product) continue;
      await _productRepo.adjustStock(item.referenceId, reverse ? item.qty : -item.qty);
    }
  }

  /// Exige aussi une connexion active — annuler une vente est une
  /// transaction au même titre que la créer. Réintègre le stock des
  /// produits de la vente annulée.
  Future<void> cancel(String id) async {
    final sale = byId(id);
    if (sale == null || sale.status == SaleStatus.annulee) return;
    await _sync.requireActiveConnection();
    final previousStatus = sale.status;
    sale.status = SaleStatus.annulee;
    try {
      await _pushToFirestoreOrThrow(sale);
    } catch (_) {
      sale.status = previousStatus;
      rethrow;
    }
    await _applyStockDelta(sale.items, reverse: true);
  }

  Future<void> delete(String id) async {
    _cache.remove(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  /// Supprime toutes les ventes (Firestore + cache) — utilisé par la
  /// réinitialisation des données depuis Paramètres. Ne touche pas au
  /// stock : une réinitialisation efface l'historique, elle ne doit pas
  /// réintégrer/décrémenter quoi que ce soit.
  Future<void> deleteAll() async {
    final ids = _cache.all.map((s) => s.id).toList();
    for (final id in ids) {
      await _sync.deleteDoc(_collection, id);
    }
    _cache.replaceAll({});
  }

  /// Récupère les ventes depuis Firestore (seule base de données) et
  /// remplace le cache en mémoire. À appeler au démarrage/après connexion —
  /// si Firestore est injoignable, le cache reste tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    final map = <String, SaleModel>{
      for (final data in docs) data['id'] as String: _fromFirestore(data),
    };
    _cache.replaceAll(map);
  }

  Future<void> _pushToFirestoreOrThrow(SaleModel sale) {
    return _sync.pushDocOrThrow(_collection, sale.id, _toMap(sale));
  }

  Map<String, dynamic> _toMap(SaleModel sale) => {
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
      };

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
