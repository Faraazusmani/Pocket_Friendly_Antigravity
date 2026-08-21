class CurrencyFormatter {
  /// Centrally formats transaction and account balances across all screens and states.
  /// Correctly handles currency symbols, decimal grouping, negative amounts, and Privacy Mode.
  static String format(int amountInMinorUnits, String currency, {bool privacyMode = false}) {
    if (privacyMode) return '••••';
    
    final isNegative = amountInMinorUnits < 0;
    final absAmount = amountInMinorUnits.abs();
    final double amt = absAmount / 100.0;
    
    final symbol = currency.toUpperCase() == 'INR'
        ? '₹'
        : (currency.toUpperCase() == 'USD'
            ? '\$'
            : (currency.toUpperCase() == 'EUR'
                ? '€'
                : (currency.toUpperCase() == 'GBP' ? '£' : '$currency ')));

    final digits = amt.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
      count++;
    }
    
    final formattedDigits = buffer.toString().split('').reversed.join('');
    return '${isNegative ? '-' : ''}$symbol$formattedDigits';
  }
}
