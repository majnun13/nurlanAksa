import 'package:intl/intl.dart';

class AksaFormatters {
  static String percent(double value) {
    return "${(value * 100).round()}%";
  }

  static String oneDecimal(double value) {
    return value.toStringAsFixed(1);
  }

  static String dateShort(DateTime date) {
    final formatter = DateFormat("dd.MM.yyyy");
    return formatter.format(date);
  }

  static String dayName(DateTime date) {
    final formatter = DateFormat.E("tr_TR");
    return formatter.format(date);
  }
}