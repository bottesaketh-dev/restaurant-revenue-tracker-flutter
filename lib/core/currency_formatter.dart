import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(dynamic amount, {int decimalDigits = 2}) {
    if (amount == null) return '₹0.00';
    num parsedAmount;
    if (amount is num) {
      parsedAmount = amount;
    } else {
      parsedAmount = double.tryParse(amount.toString()) ?? 0.0;
    }
    
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: decimalDigits,
    );
    return formatter.format(parsedAmount);
  }

  static String formatNoSymbol(dynamic amount, {int decimalDigits = 2}) {
    if (amount == null) return '0.00';
    num parsedAmount;
    if (amount is num) {
      parsedAmount = amount;
    } else {
      parsedAmount = double.tryParse(amount.toString()) ?? 0.0;
    }
    
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: decimalDigits,
    );
    return formatter.format(parsedAmount).trim();
  }
}
