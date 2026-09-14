import 'package:hive/hive.dart';

import 'enums.dart';
import 'sale_item_model.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 4)
class SaleModel extends HiveObject {
  @HiveField(0)
  String id; // VTE-XXXX
  @HiveField(1)
  DateTime date;
  @HiveField(2)
  String sellerId;
  @HiveField(3)
  String sellerName;
  @HiveField(4)
  String sellerRole;
  @HiveField(5)
  Workstation workstation;
  @HiveField(6)
  String? clientId;
  @HiveField(7)
  String clientName;
  @HiveField(8)
  String clientPhone;
  @HiveField(9)
  List<SaleItemModel> items;
  @HiveField(10)
  double discount;
  @HiveField(11)
  PaymentMethod paymentMethod;
  @HiveField(12)
  SaleStatus status;
  @HiveField(13)
  int loyaltyPointsEarned;
  @HiveField(14)
  DateTime createdAt;

  SaleModel({
    required this.id,
    required this.date,
    required this.sellerId,
    required this.sellerName,
    required this.sellerRole,
    required this.workstation,
    this.clientId,
    this.clientName = 'Client anonyme',
    this.clientPhone = '',
    required this.items,
    this.discount = 0,
    required this.paymentMethod,
    this.status = SaleStatus.complete,
    this.loyaltyPointsEarned = 0,
    required this.createdAt,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.sum);
  double get total => (subtotal - discount).clamp(0, double.infinity);

  /// Répartit [total] (donc après remise) entre produits et services.
  ///
  /// Une vente n'est PAS toujours d'un seul type : le poste Admin vend depuis
  /// un panier unifié qui peut mélanger produits et services dans une même
  /// vente (reçu "mixte", spec §9). Attribuer le CA par `sale.workstation`
  /// ferait disparaître ces ventes admin des totaux POS/Beauté ; on répartit
  /// donc au prorata du sous-total de chaque type de ligne à la place.
  ({double product, double beauty}) revenueSplit() {
    if (subtotal <= 0) return (product: 0, beauty: 0);
    final productSubtotal =
        items.where((i) => i.type == SaleItemType.product).fold<double>(0, (sum, i) => sum + i.sum);
    final productShare = productSubtotal / subtotal;
    final productRevenue = total * productShare;
    return (product: productRevenue, beauty: total - productRevenue);
  }
}
