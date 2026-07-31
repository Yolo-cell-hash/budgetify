import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/models/bank_summary.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/bank_alias_service.dart';
import 'package:budget_tracker/services/bank_directory.dart';

TransactionModel _txn({
  required double amount,
  required String sender,
  TransactionType type = TransactionType.debit,
  String? category,
  double? splitShare,
  bool isManual = false,
  DateTime? at,
}) {
  return TransactionModel(
    amount: amount,
    type: type,
    sender: sender,
    message: 'test',
    detectedAt: at ?? DateTime(2026, 7, 15),
    category: category,
    splitShare: splitShare,
    isManual: isManual,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => BankAliasService.resetForTest(const {}));

  group('Bank aliases', () {
    test('a user name replaces the detected one everywhere', () {
      BankAliasService.resetForTest({'HDFC Bank': 'HDFC Salary'});
      final identity = BankDirectory.forSender('VM-HDFCBK-S');
      expect(identity.name, 'HDFC Salary');
      expect(identity.defaultName, 'HDFC Bank');
      expect(identity.isRenamed, isTrue);
    });

    test('renaming does not move a rupee: the id is untouched', () {
      final before = BankDirectory.forSender('VM-HDFCBK-S').id;
      BankAliasService.resetForTest({'HDFC Bank': 'HDFC Salary'});
      final after = BankDirectory.forSender('VM-HDFCBK-S');
      expect(after.id, before);
      // …and a different header for the same bank still lands in that row.
      expect(BankDirectory.forSender('AD-HDFCBN-T').id, before);
      expect(BankDirectory.forSender('AD-HDFCBN-T').name, 'HDFC Salary');
    });

    test('one alias covers every header the bank sends from', () {
      BankAliasService.resetForTest({'State Bank of India': 'Joint account'});
      for (final header in ['SBIUPI', 'SBIINB', 'ATMSBI']) {
        expect(BankDirectory.forSender('BV-$header-S').name, 'Joint account',
            reason: header);
      }
    });

    test('an unnameable header becomes whatever the user calls it', () {
      BankAliasService.resetForTest({'ZZZTOP': 'Cooperative savings'});
      final identity = BankDirectory.forSender('AD-ZZZTOP-T');
      expect(identity.name, 'Cooperative savings');
      expect(identity.kind, BankKind.unknown); // still honestly unmapped
      expect(identity.isRenamed, isTrue);
      expect(identity.id, 'ZZZTOP'); // still wired to the same header
    });

    test('totals follow the renamed bank, not the old label', () {
      BankAliasService.resetForTest({'ZZZTOP': 'Cooperative savings'});
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 300, sender: 'VM-ZZZTOP-S'),
        _txn(amount: 200, sender: 'AD-ZZZTOP-T'),
      ]);
      expect(breakdown.bankCount, 1);
      expect(breakdown.banks.single.name, 'Cooperative savings');
      expect(breakdown.banks.single.spent, 500);
      // The filter key stays the header, so saved filters keep working.
      expect(breakdown.forId('ZZZTOP'), isNotNull);
    });

    test('manual and imported buckets can be renamed too', () {
      BankAliasService.resetForTest({
        '__manual__': 'Cash book',
        'import:OLD LEDGER': '2024 ledger',
      });
      final manual = BankDirectory.resolve(
          _txn(amount: 10, sender: 'Manual entry', isManual: true));
      expect(manual.name, 'Cash book');
      expect(manual.id, '__manual__');
      expect(BankDirectory.forSender('IMPORT-OLD LEDGER').name, '2024 ledger');
    });

    test('no alias means the detected name, unchanged', () {
      final identity = BankDirectory.forSender('VM-HDFCBK-S');
      expect(identity.name, 'HDFC Bank');
      expect(identity.defaultName, 'HDFC Bank');
      expect(identity.isRenamed, isFalse);
    });

    test('forId reads the current name for a bare id', () {
      BankAliasService.resetForTest({'HDFC Bank': 'HDFC Salary'});
      expect(BankDirectory.forId('HDFC Bank', 'HDFC Bank'), 'HDFC Salary');
      expect(BankDirectory.forId('Axis Bank', 'Axis Bank'), 'Axis Bank');
    });
  });

  group('Bank aliases · backup', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      BankAliasService.resetForTest(const {});
    });

    test('names survive a backup and restore', () async {
      BankAliasService.resetForTest({
        'HDFC Bank': 'HDFC Salary',
        'ZZZTOP': 'Cooperative savings',
      });
      // Through JSON, as the real payload goes.
      final payload = jsonDecode(jsonEncode(BankAliasService().exportSettings()))
          as Map<String, dynamic>;

      BankAliasService.resetForTest(const {}); // fresh device
      await BankAliasService().importSettings(payload);

      expect(BankDirectory.forSender('VM-HDFCBK-S').name, 'HDFC Salary');
      expect(BankDirectory.forSender('AD-ZZZTOP-T').name, 'Cooperative savings');
    });

    test('restoring does not wipe names set on this device', () async {
      // Restore is additive everywhere else in the app; a name the user set
      // after the backup was taken must not vanish when they restore it.
      BankAliasService.resetForTest({'Axis Bank': 'Rent account'});
      await BankAliasService()
          .importSettings(const {'aliases': {'HDFC Bank': 'HDFC Salary'}});

      expect(BankAliasService().aliasFor('Axis Bank'), 'Rent account');
      expect(BankAliasService().aliasFor('HDFC Bank'), 'HDFC Salary');
    });

    test('on a conflict the backup wins', () async {
      BankAliasService.resetForTest({'HDFC Bank': 'Old name'});
      await BankAliasService()
          .importSettings(const {'aliases': {'HDFC Bank': 'Backed-up name'}});
      expect(BankAliasService().aliasFor('HDFC Bank'), 'Backed-up name');
    });

    test('a missing or malformed payload leaves names alone', () async {
      BankAliasService.resetForTest({'HDFC Bank': 'HDFC Salary'});
      await BankAliasService().importSettings(null);
      await BankAliasService().importSettings(const {});
      await BankAliasService().importSettings(const {'aliases': 'nonsense'});
      await BankAliasService().importSettings(const {
        'aliases': {'Axis Bank': 42, 'Bank of India': '   '},
      });
      expect(BankAliasService().aliasFor('HDFC Bank'), 'HDFC Salary');
      // Junk entries are skipped rather than stored as empty names.
      expect(BankAliasService().aliasFor('Axis Bank'), isNull);
      expect(BankAliasService().aliasFor('Bank of India'), isNull);
    });

    test('a blank name clears the alias rather than storing whitespace',
        () async {
      BankAliasService.resetForTest({'HDFC Bank': 'HDFC Salary'});
      await BankAliasService().setAlias('HDFC Bank', '   ');
      expect(BankAliasService().aliasFor('HDFC Bank'), isNull);
      expect(BankDirectory.forSender('VM-HDFCBK-S').name, 'HDFC Bank');
    });

    test('names persist to storage and reload', () async {
      BankAliasService.resetForTest(const {});
      await BankAliasService().setAlias('HDFC Bank', 'HDFC Salary');
      // Simulate the next app launch: cold cache, initialize() reads prefs.
      BankAliasService.resetForTest();
      await BankAliasService().initialize();
      expect(BankAliasService().aliasFor('HDFC Bank'), 'HDFC Salary');
    });
  });

  group('BankDirectory header resolution', () {
    test('reads the banks behind the common DLT headers', () {
      expect(BankDirectory.bankForHeader('HDFCBK'), 'HDFC Bank');
      expect(BankDirectory.bankForHeader('BOIIND'), 'Bank of India');
      expect(BankDirectory.bankForHeader('SBIUPI'), 'State Bank of India');
      expect(BankDirectory.bankForHeader('ICICIB'), 'ICICI Bank');
      expect(BankDirectory.bankForHeader('AXISBK'), 'Axis Bank');
      expect(BankDirectory.bankForHeader('MAHABK'), 'Bank of Maharashtra');
      expect(BankDirectory.bankForHeader('KOTAKB'), 'Kotak Mahindra Bank');
    });

    test('lookup is case-insensitive and ignores surrounding space', () {
      expect(BankDirectory.bankForHeader(' hdfcbk '), 'HDFC Bank');
    });

    test('strips the DLT operator prefix and route suffix', () {
      // The same alert arrives under different routes and circles; all of
      // them are one bank.
      for (final sender in ['VM-HDFCBK-S', 'AD-HDFCBK-T', 'HDFCBK']) {
        expect(BankDirectory.forSender(sender).name, 'HDFC Bank',
            reason: sender);
      }
    });

    test('every SBI header lands in one bucket, not 273', () {
      final ids = ['SBIUPI', 'SBIINB', 'SBIPSG', 'ATMSBI', 'SBISMS']
          .map((h) => BankDirectory.forSender('BV-$h-S').id)
          .toSet();
      expect(ids, {'State Bank of India'});
    });

    test('headers the app allowlists but the registry omits still resolve',
        () {
      expect(BankDirectory.forSender('JD-MAHABNK').name,
          'Bank of Maharashtra');
      expect(BankDirectory.forSender('AX-BOMSMS-S').name,
          'Bank of Maharashtra');
      expect(BankDirectory.forSender('VM-AXISBNK').name, 'Axis Bank');
      // Saraswat is absent from the registry entirely; its account and card
      // headers must land on one identity so card spends group with the
      // account's SMS instead of standing up an unnamed "SBCARD" row.
      expect(BankDirectory.forSender('JX-SARBNK-S').name,
          'Saraswat Co-operative Bank');
      expect(BankDirectory.forSender('JX-SBCARD-S').name,
          'Saraswat Co-operative Bank');
      expect(BankDirectory.forSender('JX-SBCARD-S').id,
          BankDirectory.forSender('JX-SARBNK-S').id);
    });

    test('full-name senders resolve by the bank named in them', () {
      expect(BankDirectory.forSender('Bank of Maharashtra').name,
          'Bank of Maharashtra');
      expect(BankDirectory.forSender('IDBI BANK LIMITED').name, 'IDBI Bank');
    });

    test('"State Bank of India" is not read as "Bank of India"', () {
      expect(BankDirectory.forSender('STATE BANK OF INDIA').name,
          'State Bank of India');
      expect(BankDirectory.forSender('UNION BANK OF INDIA').name,
          'Union Bank of India');
      expect(BankDirectory.forSender('BANK OF INDIA').name, 'Bank of India');
    });

    test('an unknown header groups under itself rather than a wrong name', () {
      final id = BankDirectory.forSender('VM-ZZZTOP-S');
      expect(id.kind, BankKind.unknown);
      expect(id.name, 'ZZZTOP');
      expect(id.isUnnamed, isFalse); // there IS a header to show
      // Still stable: two alerts from the same unknown bank group together,
      // across operator prefixes and route suffixes.
      expect(BankDirectory.forSender('AD-ZZZTOP-T').id, id.id);
      expect(BankDirectory.forSender('ZZZTOP').id, id.id);
    });

    test('an undetected bank still totals and ranks like any other', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 300, sender: 'VM-ZZZTOP-S'),
        _txn(amount: 200, sender: 'AD-ZZZTOP-T'),
        _txn(amount: 100, sender: 'VM-HDFCBK-S'),
      ]);
      expect(breakdown.bankCount, 2);
      final unknown = breakdown.banks.first;
      expect(unknown.name, 'ZZZTOP');
      expect(unknown.spent, 500);
      expect(unknown.expenseCount, 2);
      expect(breakdown.totalSpent, 600);
    });

    test('a blank sender is unknown, never filed as the user\'s own entry',
        () {
      // Nobody typed this in — a malformed message or a bad import. Filing
      // it under "Added by you" would misattribute where the money went.
      final orphan = _txn(amount: 100, sender: '   ');
      final identity = BankDirectory.resolve(orphan);
      expect(identity.kind, BankKind.unknown);
      expect(identity.isUnnamed, isTrue);
      expect(identity, isNot(BankIdentity.manual));
      // …and it keeps its own row rather than joining manual entries.
      final breakdown = BankBreakdown.fromTransactions([
        orphan,
        _txn(amount: 50, sender: 'Manual entry', isManual: true),
      ]);
      expect(breakdown.bankCount, 2);
    });

    test('neobank and fintech headers the registry omits are still named',
        () {
      const expected = {
        'DM-JUPITR': 'Jupiter',
        'AX-FIMONY-S': 'Fi Money',
        'VM-NIYOGB': 'Niyo',
        'JD-BANDHN-T': 'Bandhan Bank',
        'AD-CBIINB': 'Central Bank of India',
        'VM-SCBLTD-S': 'Standard Chartered',
      };
      expected.forEach((sender, bank) {
        final id = BankDirectory.forSender(sender);
        expect(id.name, bank, reason: sender);
        expect(id.kind, BankKind.bank, reason: sender);
      });
    });

    test('manual entries group on the flag, not the localised sender', () {
      final english = _txn(amount: 100, sender: 'Manual entry', isManual: true);
      final hindi = _txn(amount: 100, sender: 'मैनुअल एंट्री', isManual: true);
      expect(BankDirectory.resolve(english), BankDirectory.resolve(hindi));
      expect(BankDirectory.resolve(english).kind, BankKind.manual);
    });

    test('a statement import merges with the bank named in its label', () {
      final identity = BankDirectory.forSender('IMPORT-HDFC SAVINGS');
      expect(identity.name, 'HDFC Bank');
      expect(identity.kind, BankKind.bank);
      // …and matches the SMS side, so one bank stays one row.
      expect(identity.id, BankDirectory.forSender('VM-HDFCBK-S').id);
    });

    test('an import label naming no bank keeps its own label', () {
      final identity = BankDirectory.forSender('IMPORT-OLD LEDGER');
      expect(identity.kind, BankKind.imported);
      expect(identity.name, 'OLD LEDGER');
    });
  });

  group('BankBreakdown', () {
    test('only banks used in the period appear', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 500, sender: 'VM-HDFCBK-S'),
        _txn(amount: 300, sender: 'VM-HDFCBK-S'),
      ]);
      expect(breakdown.bankCount, 1);
      expect(breakdown.banks.single.name, 'HDFC Bank');
      expect(breakdown.banks.single.spent, 800);
      expect(breakdown.banks.single.expenseCount, 2);
    });

    test('two banks used means two rows, ranked by spend', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 200, sender: 'BV-SBIUPI-S'),
        _txn(amount: 900, sender: 'VM-HDFCBK-S'),
        _txn(amount: 100, sender: 'BV-SBIUPI-S'),
      ]);
      expect(breakdown.banks.map((b) => b.name),
          ['HDFC Bank', 'State Bank of India']);
      expect(breakdown.totalSpent, 1200);
      expect(breakdown.topSpender!.name, 'HDFC Bank');
      expect(breakdown.share(breakdown.banks.first), closeTo(0.75, 1e-9));
      expect(breakdown.barFraction(breakdown.banks.last),
          closeTo(300 / 900, 1e-9));
    });

    test('self transfers, investments and settlements are not spending', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 400, sender: 'VM-HDFCBK-S', category: 'Groceries'),
        _txn(amount: 5000, sender: 'VM-HDFCBK-S', category: 'Self Transfer'),
        _txn(amount: 2000, sender: 'VM-HDFCBK-S', category: 'Investments'),
        _txn(amount: 300, sender: 'VM-HDFCBK-S', category: 'Settlement'),
      ]);
      final hdfc = breakdown.banks.single;
      expect(hdfc.spent, 400);
      expect(hdfc.expenseCount, 1);
      expect(hdfc.moved, 7300);
      expect(hdfc.movedCount, 3);
      expect(hdfc.transactionCount, 4);
      expect(breakdown.totalSpent, 400);
    });

    test('a month of nothing but self-transfers shows the bank at zero spend',
        () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 5000, sender: 'BV-SBIUPI-S', category: 'Self Transfer'),
      ]);
      expect(breakdown.bankCount, 1);
      expect(breakdown.totalSpent, 0);
      expect(breakdown.banks.single.moved, 5000);
      expect(breakdown.topSpender, isNull);
      expect(breakdown.spenders, isEmpty);
      // No divide-by-zero in the bar maths when nothing was spent.
      expect(breakdown.barFraction(breakdown.banks.single), 0);
      expect(breakdown.share(breakdown.banks.single), 0);
    });

    test('credits count as income, and non-income credits do not', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(
          amount: 50000,
          sender: 'VM-HDFCBK-S',
          type: TransactionType.credit,
          category: 'Salary',
        ),
        _txn(
          amount: 9000,
          sender: 'VM-HDFCBK-S',
          type: TransactionType.credit,
          category: 'Self Transfer',
        ),
        _txn(amount: 1000, sender: 'VM-HDFCBK-S', category: 'Shopping'),
      ]);
      final hdfc = breakdown.banks.single;
      expect(hdfc.received, 50000);
      expect(hdfc.incomeCount, 1);
      expect(hdfc.moved, 9000);
      expect(hdfc.spent, 1000);
      expect(hdfc.net, 49000);
      expect(breakdown.totalReceived, 50000);
    });

    test('a split debit counts only the user\'s share', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 1200, splitShare: 400, sender: 'VM-HDFCBK-S'),
      ]);
      expect(breakdown.banks.single.spent, 400);
      expect(breakdown.totalSpent, 400);
    });

    test('manual and imported money keep their own rows', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 250, sender: 'Manual entry', isManual: true),
        _txn(amount: 750, sender: 'IMPORT-OLD LEDGER'),
        _txn(amount: 100, sender: 'VM-HDFCBK-S'),
      ]);
      expect(breakdown.bankCount, 3);
      expect(
        breakdown.banks.map((b) => b.name).toSet(),
        {'Manual entry', 'OLD LEDGER', 'HDFC Bank'},
      );
    });

    test('averages and lookups', () {
      final breakdown = BankBreakdown.fromTransactions([
        _txn(amount: 100, sender: 'VM-HDFCBK-S'),
        _txn(amount: 300, sender: 'VM-HDFCBK-S'),
      ]);
      expect(breakdown.forId('HDFC Bank')!.averageSpend, 200);
      expect(breakdown.forId('Axis Bank'), isNull);
    });

    test('no transactions means no banks', () {
      final breakdown = BankBreakdown.fromTransactions(const []);
      expect(breakdown.isEmpty, isTrue);
      expect(breakdown.totalSpent, 0);
      expect(breakdown.topSpender, isNull);
    });
  });
}
