import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/financial_health_service.dart';
import 'package:budget_tracker/widgets/financial_health_card.dart';

// A fully-scored profile → composite 97 (Excellent).
const _scored = FinancialHealth(
  income: 100000,
  expenses: 80000, // savings → 100
  budgets: [BudgetUsage(limit: 80000, spent: 80000)], // → 100
  recurringMonthly: 20000, // → 100
  assets: 500000,
  liabilities: 100000, // equity ~83
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FinancialHealthCard (full)', () {
    testWidgets('renders the gauge, band and per-pillar breakdown',
        (tester) async {
      await _pump(tester, const FinancialHealthCard(health: _scored));

      expect(find.text('Financial Health'), findsOneWidget);
      expect(find.text('Excellent'), findsOneWidget);
      expect(find.text('97'), findsOneWidget); // gauge centre after count-up
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
      await _pump(
        tester,
        const FinancialHealthCard(
          health: FinancialHealth(income: 0, expenses: 0),
        ),
      );
      expect(find.textContaining('will appear here'), findsOneWidget);
      expect(find.text('Excellent'), findsNothing);
    });

    testWidgets('the info button opens the "how it works" explainer',
        (tester) async {
      await _pump(tester, const FinancialHealthCard(health: _scored));

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('How your score works'), findsOneWidget);
      expect(find.textContaining('35%'), findsOneWidget);
      expect(find.textContaining('25%'), findsOneWidget);
    });
  });

  group('FinancialHealthInline (compact)', () {
    testWidgets('shows the score as value/100 and opens the explainer on tap',
        (tester) async {
      await _pump(tester, const FinancialHealthInline(health: _scored));

      expect(find.text('FINANCIAL HEALTH'), findsOneWidget);
      expect(find.text('97'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('How your score works'), findsOneWidget);
    });

    testWidgets('renders nothing when there is no score yet', (tester) async {
      await _pump(
        tester,
        const FinancialHealthInline(
          health: FinancialHealth(income: 0, expenses: 0),
        ),
      );
      expect(find.text('FINANCIAL HEALTH'), findsNothing);
    });
  });
}
