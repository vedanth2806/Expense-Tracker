import 'package:intl/intl.dart';

String formatRupees(double amount, {int decimalDigits = 2}) {
  final format = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimalDigits,
  );
  return format.format(amount);
}

String formatIndianNumber(double amount, {int decimalDigits = 0}) {
  final format = NumberFormat.decimalPattern('en_IN');
  format.minimumFractionDigits = decimalDigits;
  format.maximumFractionDigits = decimalDigits;
  return format.format(amount);
}
