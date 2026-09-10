import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _rupeeFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _rupeeDecimalFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(double amount, {bool showDecimals = false}) {
    if (showDecimals || amount % 1 != 0) {
      return _rupeeDecimalFormat.format(amount);
    }
    return _rupeeFormat.format(amount);
  }
}
