/// Règles de tarification automatiques appliquées à la caisse.
class Pricing {
  Pricing._();

  /// À partir de ce nombre d'unités d'un même article dans une vente (ce
  /// seuil inclus), la remise quantité s'applique automatiquement.
  static const double bulkDiscountThreshold = 3;

  /// Taux de la remise quantité automatique.
  static const double bulkDiscountRate = 0.10;

  static bool appliesBulkDiscount(double qty) => qty >= bulkDiscountThreshold;

  /// Total d'une ligne (quantité × prix unitaire), avec la remise quantité
  /// automatique appliquée si `qty` atteint [bulkDiscountThreshold] — sauf
  /// si `eligible` est `false` (réglage par produit, décidé par l'admin).
  static double lineTotal(double qty, double unitPrice, {bool eligible = true}) {
    final total = qty * unitPrice;
    return eligible && appliesBulkDiscount(qty) ? total * (1 - bulkDiscountRate) : total;
  }
}
