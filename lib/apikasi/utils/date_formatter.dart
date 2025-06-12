import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final formatter = DateFormat('d MMMM yyyy', 'id_ID');
    return formatter.format(date);
  }

  static String formatDateWithDay(String dateString) {
    final date = DateTime.parse(dateString);
    final formatter = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    return formatter.format(date);
  }

  static String getTodayDate() {
    return DateTime.now().toIso8601String().split('T')[0];
  }
}
