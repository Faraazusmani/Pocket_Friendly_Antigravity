import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/utilities/currency_formatter.dart';

void main() {
  group('CurrencyFormatter tests', () {
    test('formats positive amounts correctly', () {
      expect(CurrencyFormatter.format(150000, 'INR'), '₹1,500');
      expect(CurrencyFormatter.format(500, 'USD'), '\$5');
      expect(CurrencyFormatter.format(12345678, 'EUR'), '€123,457');
    });

    test('formats negative amounts correctly', () {
      expect(CurrencyFormatter.format(-150000, 'INR'), '-₹1,500');
      expect(CurrencyFormatter.format(-500, 'USD'), '-\$5');
    });

    test('respects privacy mode', () {
      expect(CurrencyFormatter.format(150000, 'INR', privacyMode: true), '••••');
      expect(CurrencyFormatter.format(-500, 'USD', privacyMode: true), '••••');
    });
  });
}
