import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/financial_year.dart';

/// The Apr–Mar boundary is the whole ballgame; these pin it down.
void main() {
  group('FinancialYear.forDate', () {
    test('April 1 opens a new FY', () {
      expect(FinancialYear.forDate(DateTime(2025, 4, 1)).startYear, 2025);
    });

    test('March 31 still belongs to the FY that opened last April', () {
      expect(FinancialYear.forDate(DateTime(2026, 3, 31)).startYear, 2025);
    });

    test('Jan–Mar roll back to the previous calendar year', () {
      expect(FinancialYear.forDate(DateTime(2026, 1, 15)).startYear, 2025);
      expect(FinancialYear.forDate(DateTime(2026, 2, 28)).startYear, 2025);
    });

    test('Apr–Dec stay in the current calendar year', () {
      expect(FinancialYear.forDate(DateTime(2025, 4, 30)).startYear, 2025);
      expect(FinancialYear.forDate(DateTime(2025, 12, 31)).startYear, 2025);
    });
  });

  group('window is half-open [start, endExclusive)', () {
    const fy = FinancialYear(2025);
    test('bounds', () {
      expect(fy.start, DateTime(2025, 4, 1));
      expect(fy.endExclusive, DateTime(2026, 4, 1));
    });

    test('contains April 1 00:00 but not next April 1 00:00', () {
      expect(fy.contains(DateTime(2025, 4, 1)), isTrue);
      expect(fy.contains(DateTime(2026, 3, 31, 23, 59, 59, 999)), isTrue);
      expect(fy.contains(DateTime(2026, 4, 1)), isFalse);
      expect(fy.contains(DateTime(2025, 3, 31, 23, 59)), isFalse);
    });
  });

  group('label', () {
    test('two-digit zero-padded end year', () {
      expect(const FinancialYear(2025).label, 'FY 2025-26');
      expect(const FinancialYear(2009).label, 'FY 2009-10');
      expect(const FinancialYear(1999).label, 'FY 1999-00');
    });
  });

  test('recent() is newest-first and never in the future', () {
    final list = FinancialYear.recent(count: 3);
    expect(list.length, 3);
    expect(list.first.startYear, greaterThanOrEqualTo(list.last.startYear));
    expect(list[0].startYear - list[1].startYear, 1);
  });

  test('previous / next step by one year', () {
    expect(const FinancialYear(2025).previous, const FinancialYear(2024));
    expect(const FinancialYear(2025).next, const FinancialYear(2026));
  });
}
