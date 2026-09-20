import 'package:hive/hive.dart';

import '../../core/utils/pricing.dart';
import 'enums.dart';

part 'sale_item_model.g.dart';

@HiveType(typeId: 5)
class SaleItemModel {
  @HiveField(0)
  String id;
  @HiveField(1)
  SaleItemType type;
  @HiveField(2)
  String referenceId;
  @HiveField(3)
  String title;
  @HiveField(4)
  String? category;
  @HiveField(5)
  String unit;
  @HiveField(6)
  String? color;
  @HiveField(7)
  double qty;
  @HiveField(8)
  double unitPrice;

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
  });

  bool get hasBulkDiscount => Pricing.appliesBulkDiscount(qty);

  double get sum => Pricing.lineTotal(qty, unitPrice);
}
