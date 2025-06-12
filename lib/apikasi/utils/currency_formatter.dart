import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(int value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(value)}';
  }
}