class CurrencyFormatter {
  static String activeSymbol = '₹';
  static String activeCurrencyCode = 'INR';

  static void setCurrency({required String symbol, String code = 'INR'}) {
    activeSymbol = symbol;
    activeCurrencyCode = code.toUpperCase();
  }

  /// Determines if the provided or active currency belongs to the Indian numbering system.
  static bool isIndianCurrency({String? code, String? symbol}) {
    const indianCodes = {'INR', 'NPR', 'BDT', 'PKR', 'LKR'};
    const indianSymbols = {'₹', 'rs', 'rs.', 'inr'};

    if (code != null && symbol == null) {
      return indianCodes.contains(code.trim().toUpperCase());
    }

    if (symbol != null && code == null) {
      return indianSymbols.contains(symbol.trim().toLowerCase());
    }

    final effectiveCode = (code ?? activeCurrencyCode).trim().toUpperCase();
    final effectiveSymbol = (symbol ?? activeSymbol).trim().toLowerCase();

    return indianCodes.contains(effectiveCode) || indianSymbols.contains(effectiveSymbol);
  }

  /// Formats integer digits according to the Indian numbering system (Lakhs, Crores).
  /// Grouping: last 3 digits, then pairs of 2 digits (e.g. 12,34,56,789).
  static String formatIndianInteger(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    final remaining = digits.substring(0, digits.length - 3);

    final buffer = StringBuffer();
    final remLen = remaining.length;
    for (int i = 0; i < remLen; i++) {
      buffer.write(remaining[i]);
      final charsLeft = remLen - 1 - i;
      if (charsLeft > 0 && charsLeft % 2 == 0) {
        buffer.write(',');
      }
    }
    buffer.write(',');
    buffer.write(last3);
    return buffer.toString();
  }

  /// Formats integer digits according to the International / Western numbering system.
  /// Grouping: groups of 3 digits (e.g. 123,456,789).
  static String formatWesternInteger(String digits) {
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final len = digits.length;
    for (int i = 0; i < len; i++) {
      buffer.write(digits[i]);
      final charsLeft = len - 1 - i;
      if (charsLeft > 0 && charsLeft % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  /// Formats a monetary amount with currency symbol and appropriate grouping commas.
  static String format(
    dynamic amount, {
    String? symbol,
    String? code,
    int decimalDigits = 2,
  }) {
    final currSymbol = symbol ?? activeSymbol;

    if (amount == null) {
      final zeroFormatted = decimalDigits > 0 ? '0.${'0' * decimalDigits}' : '0';
      return '$currSymbol $zeroFormatted';
    }

    num parsedAmount;
    if (amount is num) {
      parsedAmount = amount;
    } else {
      final sanitized = amount.toString().replaceAll(',', '').trim();
      parsedAmount = double.tryParse(sanitized) ?? 0.0;
    }

    if (parsedAmount.isNaN || parsedAmount.isInfinite) {
      final zeroFormatted = decimalDigits > 0 ? '0.${'0' * decimalDigits}' : '0';
      return '$currSymbol $zeroFormatted';
    }

    final isNegative = parsedAmount < 0;
    final absAmount = parsedAmount.abs();

    final parts = absAmount.toStringAsFixed(decimalDigits).split('.');
    final intPart = parts[0];

    final useIndian = isIndianCurrency(code: code, symbol: symbol);
    final formattedInt = useIndian
        ? formatIndianInteger(intPart)
        : formatWesternInteger(intPart);

    final decimalPart = (decimalDigits > 0 && parts.length > 1) ? '.${parts[1]}' : '';
    final formattedNumber = '$formattedInt$decimalPart';

    return isNegative ? '$currSymbol -$formattedNumber' : '$currSymbol $formattedNumber';
  }

  /// Formats a monetary amount without the currency symbol using appropriate grouping commas.
  static String formatNoSymbol(
    dynamic amount, {
    String? code,
    String? symbol,
    int decimalDigits = 2,
  }) {
    if (amount == null) {
      return decimalDigits > 0 ? '0.${'0' * decimalDigits}' : '0';
    }

    num parsedAmount;
    if (amount is num) {
      parsedAmount = amount;
    } else {
      final sanitized = amount.toString().replaceAll(',', '').trim();
      parsedAmount = double.tryParse(sanitized) ?? 0.0;
    }

    if (parsedAmount.isNaN || parsedAmount.isInfinite) {
      return decimalDigits > 0 ? '0.${'0' * decimalDigits}' : '0';
    }

    final isNegative = parsedAmount < 0;
    final absAmount = parsedAmount.abs();

    final parts = absAmount.toStringAsFixed(decimalDigits).split('.');
    final intPart = parts[0];

    final useIndian = isIndianCurrency(code: code, symbol: symbol);
    final formattedInt = useIndian
        ? formatIndianInteger(intPart)
        : formatWesternInteger(intPart);

    final decimalPart = (decimalDigits > 0 && parts.length > 1) ? '.${parts[1]}' : '';
    final formattedNumber = '$formattedInt$decimalPart';

    return isNegative ? '-$formattedNumber' : formattedNumber;
  }
}
