import 'enums.dart';
import 'sale_item_model.dart';

class SaleModel {
  String id; // VTE-XXXX
  DateTime date;
  String sellerId;
  String sellerName;
  String sellerRole;
  Workstation workstation;
  String? clientId;
  String clientName;
  String clientPhone;
  List<SaleItemModel> items;
  double discount;
  PaymentMethod paymentMethod;
  SaleStatus status;
  int loyaltyPointsEarned;
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

  /// Répartit [total] (donc après remise) entre types de lignes (produit,
  /// service beauté, service impression).
  ///
  /// Une vente n'est PAS toujours d'un seul type : le poste Admin vend depuis
  /// un panier unifié qui peut mélanger plusieurs types dans une même vente
  /// (reçu "mixte", spec §9). Attribuer le CA par `sale.workstation` ferait
  /// disparaître ces ventes admin des totaux par poste ; on répartit donc au
  /// prorata du sous-total de chaque type de ligne à la place.
  Map<SaleItemType, double> revenueByType() {
    if (subtotal <= 0) {
      return {for (final t in SaleItemType.values) t: 0};
    }
    return {
      for (final t in SaleItemType.values)
        t: total * (items.where((i) => i.type == t).fold<double>(0, (sum, i) => sum + i.sum) / subtotal),
    };
  }
}
