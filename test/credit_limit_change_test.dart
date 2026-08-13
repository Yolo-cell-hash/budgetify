import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';
import 'package:budget_tracker/widgets/transaction_card.dart';

/// A card's credit limit moving is not money moving.
///
/// Device report, 2026-08-13: ICICI's "The credit limit for your ICICI Bank
/// Credit Card XX6528 has been changed from INR 200000 to INR 60000" was
/// sitting in the ledger as ₹2,00,000 of INCOME. Every gate that should have
/// caught it looked away — the notice arrives on the transactional -S route so
/// the promo filter never sees it, "changed from INR 200000" scores as money
/// arriving, and the card tail supplies the account evidence a soft reject
/// asks for. The limit-change rejects existed, but their noun-and-verb windows
/// were too tight to span the card sitting between "limit" and "has been
/// changed".
///
/// `sms_parser_gate_test.dart` guards the parse verdict itself. This suite goes
/// a level up to what the user actually sees: sweep a small inbox the way the
/// SMS scan does, render whatever survives, and assert the ₹2,00,000 row never
/// reaches the screen — in either theme brightness. (The real
/// TransactionsScreen loads from sqflite and the project has no test factory
/// for it, so the list is composed here from the same [TransactionCard] the
/// screen builds its rows from.)

/// The reported message, verbatim but for the masked card tail.
const _limitChangeSms = 'Dear Customer, The credit limit for your ICICI Bank '
    'Credit Card XX6528 has been changed from INR 200000 to INR 60000 on '
    '2026-08-08.';

/// A real spend on the very same card, so the sweep has something to keep —
/// a filter that drops everything would pass a "nothing on screen" assertion
/// without being right about anything.
const _genuineDebitSms = 'ICICI Bank Acct XX6528 debited for Rs 249.00 on '
    '08-Aug-26; SWIGGY credited. UPI:123834511400. Call 18002662 for dispute.';

const _sender = 'JX-ICICIT-S'; // the allowlisted header from the report
final _now = DateTime(2026, 8, 13, 9, 3);

/// What the scan keeps from an inbox, in arrival order.
List<TransactionModel> _scan(List<String> inbox) {
  final kept = <TransactionModel>[];
  for (final message in inbox) {
    final txn = SmsParserService.parseTransaction(_sender, message, _now);
    if (txn != null) kept.add(txn);
  }
  return kept;
}

Future<void> _pumpLedger(
  WidgetTester tester,
  List<TransactionModel> transactions,
  AppThemeVariant variant,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<AppPreferences>(create: (_) => AppPreferences()),
      ],
      child: MaterialApp(
        key: ValueKey(variant),
        theme: AppTheme.of(variant),
        home: Scaffold(
          body: ListView(
            children: [
              for (final t in transactions) TransactionCard(transaction: t),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a credit-limit change never becomes a transaction', () {
    test('the sweep keeps the spend and drops the notice', () {
      final kept = _scan([_limitChangeSms, _genuineDebitSms]);
      expect(kept, hasLength(1),
          reason: 'only the ₹249 spend is a transaction');
      expect(kept.single.amount, 249.0);
      expect(kept.single.type, TransactionType.debit);
    });

    testWidgets('the ₹2,00,000 row never reaches the ledger, light or dark',
        (tester) async {
      final kept = _scan([_limitChangeSms, _genuineDebitSms]);

      for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
        await _pumpLedger(tester, kept, variant);

        expect(find.byType(TransactionCard), findsOneWidget,
            reason: '$variant: one card, for the one real spend');
        // Neither end of the limit change may appear as an amount.
        expect(find.textContaining('2,00,000'), findsNothing,
            reason: '$variant: the old credit limit is on screen as money');
        expect(find.textContaining('60,000'), findsNothing,
            reason: '$variant: the new credit limit is on screen as money');
        // ...and nothing on screen claims income at all.
        expect(find.textContaining('+ ₹'), findsNothing,
            reason: '$variant: a credit row rendered');
        expect(find.textContaining('- ₹249.00'), findsOneWidget,
            reason: '$variant: the genuine spend should still show');
        expect(tester.takeException(), isNull, reason: '$variant');
      }
    });

    testWidgets('the finders above would catch the row if it came back',
        (tester) async {
      // Proves the assertions are not vacuous: hand-build the exact row the
      // misparse produced and confirm the same finders see it.
      final misparse = TransactionModel(
        amount: 200000.0,
        type: TransactionType.credit,
        sender: _sender,
        message: _limitChangeSms,
        detectedAt: _now,
        accountInfo: 'XX6528',
      );
      await _pumpLedger(tester, [misparse], AppThemeVariant.light);

      expect(find.textContaining('2,00,000'), findsOneWidget);
      expect(find.textContaining('+ ₹'), findsOneWidget);
    });
  });
}
