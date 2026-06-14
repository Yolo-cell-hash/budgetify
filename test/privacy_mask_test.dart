import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/widgets/privacy_amount.dart';

void main() {
  group('maskAmount', () {
    test('keeps symbol and sign, masks the number', () {
      expect(maskAmount('+ ₹1,234.56'), '+ ₹••••');
      expect(maskAmount('- ₹1,234.56'), '- ₹••••');
      expect(maskAmount('₹0'), '₹••••');
    });

    test('keeps surrounding words', () {
      expect(maskAmount('₹12,345 spent'), '₹•••• spent');
      expect(maskAmount('of ₹5,000'), 'of ₹••••');
      expect(maskAmount('₹2,000 left'), '₹•••• left');
    });

    test('hides magnitude (same mask regardless of size)', () {
      expect(maskAmount('₹9'), maskAmount('₹99,99,999'));
    });
  });
}
