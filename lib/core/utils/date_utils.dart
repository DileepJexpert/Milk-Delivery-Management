import 'package:intl/intl.dart';

class AppDates {
  static String dateKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime parseKey(String key) => DateTime.parse(key);

  static String prettyDate(DateTime d, {String locale = 'en'}) =>
      DateFormat.yMMMd(locale).format(d);

  static String monthKey(DateTime d) =>
      DateFormat('yyyy-MM').format(DateTime(d.year, d.month));

  static String monthLabel(DateTime d, {String locale = 'en'}) =>
      DateFormat.yMMMM(locale).format(d);
}
