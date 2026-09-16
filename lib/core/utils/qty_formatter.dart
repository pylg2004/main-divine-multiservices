/// Formatage et arrondi des quantités.
///
/// La plupart des produits se vendent à l'unité (quantité entière). Le
/// tissu ("toiles") se vend en aune, une unité de longueur qui peut être
/// fractionnée par quart (1/4, 1/2, 3/4) — voir [QtyFormatter.aune].
class QtyFormatter {
  QtyFormatter._();

  /// Pas de fractionnement autorisé pour une quantité en aune.
  static const double auneStep = 0.25;

  /// Une unité est vendue à l'aune (fractionnable) si son libellé est
  /// exactement "aune" (insensible à la casse/espaces).
  static bool isFractionalUnit(String? unit) => (unit ?? '').trim().toLowerCase() == 'aune';

  /// Arrondit [qty] au quart le plus proche (utilisé pour l'aune).
  static double roundToStep(double qty) => (qty / auneStep).round() * auneStep;

  static String format(double qty, {bool fractional = false}) {
    return fractional ? aune(qty) : plain(qty);
  }

  /// "3" ou "3.5" — quantités entières ou décimales génériques (rapports,
  /// agrégats mélangeant plusieurs types d'articles).
  static String plain(double qty) {
    if (qty == qty.roundToDouble()) return qty.round().toString();
    return qty.toStringAsFixed(2);
  }

  /// "5 1/4", "1/2", "3" — représentation en aune avec fractions au quart.
  static String aune(double qty) {
    final negative = qty < 0;
    final abs = roundToStep(qty.abs());
    var whole = abs.truncate();
    var quarters = ((abs - whole) * 4).round();
    if (quarters == 4) {
      whole += 1;
      quarters = 0;
    }
    const fractionLabels = {1: '1/4', 2: '1/2', 3: '3/4'};
    final fracLabel = fractionLabels[quarters];
    final text = fracLabel == null ? '$whole' : (whole == 0 ? fracLabel : '$whole $fracLabel');
    return negative ? '-$text' : text;
  }
}
