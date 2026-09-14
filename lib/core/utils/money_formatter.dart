import 'package:intl/intl.dart';

/// Formate les montants en Gourdes haïtiennes (HTG) par défaut.
/// La devise réelle vient de CompanySettings mais le symbole par défaut
/// couvre l'affichage avant que les paramètres ne soient chargés.
class MoneyFormatter {
  MoneyFormatter._();

  static final NumberFormat _format = NumberFormat.decimalPattern('fr');

  static String format(num amount, {String symbol = 'G'}) {
    return '${_format.format(amount)} $symbol';
  }

  static String formatCompact(num amount, {String symbol = 'G'}) {
    final compact = NumberFormat.compactCurrency(
      locale: 'fr',
      symbol: '$symbol ',
      decimalDigits: 1,
    );
    return compact.format(amount);
  }
}
