class CurrencyFormatter {
  static String activeSymbol = '₹';
  static String activeCurrencyCode = 'INR';

  static void setCurrency({required String symbol, String code = 'INR'}) {
    activeSymbol = symbol;
    activeCurrencyCode = code;
  }

  static String format(dynamic amount, {String? symbol, int decimalDigits = 2}) {
    final currSymbol = symbol ?? activeSymbol;
    if (amount == null) return '$currSymbol 0.00';
    num parsedAmount;
    if (amount is num) {
      parsedAmount = amount;
    } else {
      parsedAmount = double.tryParse(amount.toString()) ?? 0.0;
    }
    
    // Format with thousands separator
    final parts = parsedAmount.toStringAsFixed(decimalDigits).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final formatted = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    return '$currSymbol $formatted';
  }

  static String formatNoSymbol(dynamic amount, {int decimalDigits = 2}) {
    if (amount == null) return '0.00';
    num parsedAmount;
    if (amount is num) {
      parsedAmount = amount;
    } else {
      parsedAmount = double.tryParse(amount.toString()) ?? 0.0;
    }
    final parts = parsedAmount.toStringAsFixed(decimalDigits).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}
