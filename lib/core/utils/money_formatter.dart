import 'package:intl/intl.dart';

/// Formate les montants en Gourdes haïtiennes (HTG) par défaut.
/// La devise réelle vient de CompanySettings mais le symbole par défaut
/// couvre l'affichage avant que les paramètres ne soient chargés.
class MoneyFormatter {
  MoneyFormatter._();

  static final NumberFormat _format = NumberFormat.decimalPattern('fr');

  /// `NumberFormat` en locale 'fr' sépare les milliers avec une espace fine
  /// insécable (U+202F) — invisible à l'écran mais que l'imprimante ESC/POS
  /// ne sait pas encoder ("Contains invalid characters"). On la remplace
  /// par une espace normale pour rester affichable ET imprimable.
  static String _sanitize(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');

  static String format(num amount, {String symbol = 'G'}) {
    return _sanitize('${_format.format(amount)} $symbol');
  }

  static String formatCompact(num amount, {String symbol = 'G'}) {
    final compact = NumberFormat.compactCurrency(
      locale: 'fr',
      symbol: '$symbol ',
      decimalDigits: 1,
    );
    return _sanitize(compact.format(amount));
  }
}
