import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/merchant_summary.dart';

void main() {
  List<Map<String, dynamic>> rows() => [
        {'merchant': 'Swiggy', 'total': 3400.0, 'count': 11},
        {'merchant': 'Amazon', 'total': 1600.0, 'count': 4},
        {'merchant': 'Other', 'total': 1000.0, 'count': 7},
      ];

  group('MerchantSpend', () {
    test('average is total / count, and 0 when count is 0', () {
      const m = MerchantSpend(name: 'Swiggy', total: 3400, count: 11);
      expect(m.average, closeTo(309.09, 0.01));
      const empty = MerchantSpend(name: 'X', total: 0, count: 0);
      expect(empty.average, 0);
    });

    test('fromRow tolerates missing/!typed fields', () {
      final m = MerchantSpend.fromRow({'merchant': 'A', 'total': 5, 'count': 2});
      expect(m.name, 'A');
      expect(m.total, 5.0);
      expect(m.count, 2);
    });
  });

  group('MerchantSummary', () {
    test('sorts by spend desc and aggregates totals', () {
      final s = MerchantSummary.fromRows(rows());
      expect(s.isEmpty, isFalse);
      expect(s.merchantCount, 3);
      expect(s.top!.name, 'Swiggy');
      expect(s.total, 6000.0);
      expect(s.transactionCount, 22);
    });

    test('topShare, barFraction and share', () {
      final s = MerchantSummary.fromRows(rows());
      expect(s.topShare, closeTo(3400 / 6000, 1e-9));
      // Amazon bar is relative to the top (Swiggy).
      expect(s.barFraction(s.merchants[1]), closeTo(1600 / 3400, 1e-9));
      // Amazon share is of the whole period.
      expect(s.share(s.merchants[1]), closeTo(1600 / 6000, 1e-9));
    });

    test('empty summary is safe', () {
      final s = MerchantSummary.fromRows(const []);
      expect(s.isEmpty, isTrue);
      expect(s.top, isNull);
      expect(s.total, 0);
      expect(s.topShare, 0);
    });
  });
}
