/// Règles de tarification automatiques appliquées à la caisse.
class Pricing {
  Pricing._();

  /// Au-delà de ce nombre d'unités d'un même article dans une vente, la
  /// remise quantité s'applique automatiquement.
  static const double bulkDiscountThreshold = 3;

  /// Taux de la remise quantité automatique.
  static const double bulkDiscountRate = 0.10;

  static bool appliesBulkDiscount(double qty) => qty > bulkDiscountThreshold;

  /// Total d'une ligne (quantité × prix unitaire), avec la remise quantité
  /// automatique appliquée si `qty` dépasse [bulkDiscountThreshold].
  static double lineTotal(double qty, double unitPrice) {
    final total = qty * unitPrice;
    return appliesBulkDiscount(qty) ? total * (1 - bulkDiscountRate) : total;
  }
}
