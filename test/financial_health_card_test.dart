import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/financial_health_service.dart';
import 'package:budget_tracker/widgets/financial_health_card.dart';

/// A service stub that returns a fixed [FinancialHealth] so the card's
/// rendering can be exercised without touching the database.
class _FixedHealthService extends FinancialHealthService {
  final FinancialHealth health;
  _FixedHealthService(this.health);

  @override
  Future<FinancialHealth> compute({
    required double income,
    required double expenses,
    DateTime? now,
  }) async =>
      health;
}

Future<void> _pump(WidgetTester tester, FinancialHealth health) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FinancialHealthCard(
            income: health.income,
            expenses: health.expenses,
            service: _FixedHealthService(health),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the gauge, band and per-pillar breakdown', (tester) async {
    const health = FinancialHealth(
      income: 100000,
      expenses: 80000, // savings → 100
      budgets: [BudgetUsage(limit: 80000, spent: 80000)], // → 100
      recurringMonthly: 20000, // → 100
      assets: 500000,
      liabilities: 100000, // equity ~83
    ); // composite → 97 (Excellent)

    await _pump(tester, health);

    expect(find.text('Financial Health'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('97'), findsOneWidget); // gauge centre after the count-up
    expect(find.text('/ 100'), findsOneWidget);
    for (final label in const [
      'Savings rate',
      'Budget adherence',
      'Recurring load',
      'Net worth',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('shows an inviting empty state when nothing can be scored',
      (tester) async {
    await _pump(tester, const FinancialHealth(income: 0, expenses: 0));

    expect(find.text('Financial Health'), findsOneWidget);
    expect(find.textContaining('will appear here'), findsOneWidget);
    // No band/gauge in the empty state.
    expect(find.text('Excellent'), findsNothing);
  });

  testWidgets('the info button opens the "how it works" explainer',
      (tester) async {
    await _pump(
      tester,
      const FinancialHealth(income: 100000, expenses: 80000),
    );

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('How your score works'), findsOneWidget);
    expect(find.textContaining('on your device'), findsOneWidget);
    // The four pillars and their weights are spelled out.
    expect(find.textContaining('35%'), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);
  });
}
