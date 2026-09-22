import '../../core/utils/pricing.dart';
import 'enums.dart';

class SaleItemModel {
  String id;
  SaleItemType type;
  String referenceId;
  String title;
  String? category;
  String unit;
  String? color;
  double qty;
  double unitPrice;
  /// Copié depuis `ProductModel.discountEligible` au moment de la vente
  /// (toujours `true` pour les services beauté/impression, qui n'ont pas
  /// ce réglage).
  bool discountEligible;

  SaleItemModel({
    required this.id,
    required this.type,
    required this.referenceId,
    required this.title,
    this.category,
    this.unit = 'unité',
    this.color,
    required this.qty,
    required this.unitPrice,
    this.discountEligible = true,
  });

  bool get hasBulkDiscount => discountEligible && Pricing.appliesBulkDiscount(qty);

  double get sum => Pricing.lineTotal(qty, unitPrice, eligible: discountEligible);
}
