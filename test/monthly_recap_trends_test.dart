import 'package:budget_tracker/models/monthly_recap.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _txn({
  required double amount,
  required DateTime at,
  TransactionType type = TransactionType.debit,
  String? category = 'Food & Dining',
  double? splitShare,
}) =>
    TransactionModel(
      amount: amount,
      type: type,
      sender: 'TESTBNK',
      message: 'test',
      detectedAt: at,
      category: category,
      splitShare: splitShare,
    );

void main() {
  final june = DateTime(2026, 6, 1);

  group('RecapTrends.compute', () {
    test('buckets expense debits per day and finds the peak', () {
      final trends = RecapTrends.compute(
        txns: [
          _txn(amount: 500, at: DateTime(2026, 6, 3, 9)),
          _txn(amount: 250, at: DateTime(2026, 6, 3, 20)),
          _txn(amount: 4000, at: DateTime(2026, 6, 14)),
          _txn(amount: 100, at: DateTime(2026, 6, 30)),
        ],
        month: june,
        now: DateTime(2026, 7, 16), // past month → whole month tracked
      );

      expect(trends.dailySpend.length, 30);
      expect(trends.dailySpend[2], 750); // June 3rd
      expect(trends.peakDay, DateTime(2026, 6, 14));
      expect(trends.peakDayAmount, 4000);
      expect(trends.trackedDays, 30);
      // 30 days minus the three that saw spending.
      expect(trends.noSpendDays, 27);
    });

    test('busiest day is by transaction count, ties broken by amount', () {
      final trends = RecapTrends.compute(
        txns: [
          // June 5: two txns, small total.
          _txn(amount: 10, at: DateTime(2026, 6, 5, 9)),
          _txn(amount: 20, at: DateTime(2026, 6, 5, 12)),
          // June 9: two txns, bigger total → wins the tie.
          _txn(amount: 500, at: DateTime(2026, 6, 9, 9)),
          _txn(amount: 600, at: DateTime(2026, 6, 9, 12)),
          // June 20: one huge txn — peak by amount, not busiest.
          _txn(amount: 9000, at: DateTime(2026, 6, 20)),
        ],
        month: june,
        now: DateTime(2026, 7, 1),
      );

      expect(trends.busiestDay, DateTime(2026, 6, 9));
      expect(trends.busiestDayTxns, 2);
      expect(trends.peakDay, DateTime(2026, 6, 20));
    });

    test('ignores credits, non-expense categories and other months', () {
      final trends = RecapTrends.compute(
        txns: [
          _txn(
              amount: 999,
              at: DateTime(2026, 6, 2),
              type: TransactionType.credit,
              category: 'Salary'),
          _txn(amount: 999, at: DateTime(2026, 6, 2), category: 'Self Transfer'),
          _txn(amount: 999, at: DateTime(2026, 5, 31)),
          _txn(amount: 40, at: DateTime(2026, 6, 8)),
        ],
        month: june,
        now: DateTime(2026, 7, 1),
      );

      expect(trends.dailySpend[1], 0); // June 2nd: credit + self-transfer only
      expect(trends.peakDay, DateTime(2026, 6, 8));
      expect(trends.peakDayAmount, 40);
    });

    test('split transactions count at the user\'s own share', () {
      final trends = RecapTrends.compute(
        txns: [
          _txn(amount: 3000, at: DateTime(2026, 6, 10), splitShare: 1000),
        ],
        month: june,
        now: DateTime(2026, 7, 1),
      );
      expect(trends.peakDayAmount, 1000);
    });

    test('current month only tracks days up to today', () {
      final trends = RecapTrends.compute(
        txns: [
          _txn(amount: 100, at: DateTime(2026, 6, 1)),
          _txn(amount: 100, at: DateTime(2026, 6, 10)),
        ],
        month: june,
        now: DateTime(2026, 6, 10), // mid-month
      );
      expect(trends.trackedDays, 10);
      expect(trends.noSpendDays, 8); // 10 elapsed days − 2 spend days
      expect(trends.dailySpend.length, 30); // still a whole-month strip
    });

    test('an empty month has no peak and all-quiet days', () {
      final trends =
          RecapTrends.compute(txns: [], month: june, now: DateTime(2026, 7, 1));
      expect(trends.peakDay, isNull);
      expect(trends.busiestDay, isNull);
      expect(trends.noSpendDays, 30);
      expect(trends.peakSharePct(0), isNull);
    });

    test('peakSharePct reports the peak day share of the month', () {
      final trends = RecapTrends.compute(
        txns: [
          _txn(amount: 750, at: DateTime(2026, 6, 4)),
          _txn(amount: 250, at: DateTime(2026, 6, 5)),
        ],
        month: june,
        now: DateTime(2026, 7, 1),
      );
      expect(trends.peakSharePct(1000), 75);
    });
  });

  group('MonthlyRecap derived accessors', () {
    test('topCategory mirrors the first of topCategories', () {
      const cats = [
        RecapHighlight(label: 'Rent', icon: '🏠', sharePct: 48, amount: 40000),
        RecapHighlight(label: 'Food & Dining', icon: '🍔', sharePct: 21),
      ];
      final recap = MonthlyRecap(
        month: DateTime(2026, 6, 1),
        availableDays: 30,
        hasData: true,
        topCategories: cats,
      );
      expect(recap.topCategory!.label, 'Rent');
      expect(recap.topCategoryAmount, 40000);

      final empty = MonthlyRecap.insufficient(DateTime(2026, 6, 1), 3);
      expect(empty.topCategory, isNull);
      expect(empty.topCategoryAmount, isNull);
      expect(empty.trends, isNull);
      expect(empty.appTimeSeconds, 0);
    });
  });
}
