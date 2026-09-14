import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _dayMonth = DateFormat('dd/MM');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'fr');

  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static DateTime startOfWeek(DateTime d) {
    final start = d.subtract(Duration(days: d.weekday - 1));
    return startOfDay(start);
  }

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime startOfYear(DateTime d) => DateTime(d.year, 1, 1);
}
