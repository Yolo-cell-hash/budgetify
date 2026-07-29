import '../services/bank_directory.dart';
import 'transaction_model.dart';

/// One bank's activity over a period.
///
/// [spent] and [received] are the real figures: money that only moved between
/// the user's own accounts, went into investments, or settled a shared bill
/// is counted in [moved] instead, exactly as [ExpenseCategories.nonExpense]
/// defines it everywhere else in the app. A bank whose whole month was a
/// self-transfer therefore shows ₹0 spent — not a phantom expense.
class BankActivity {
  final BankIdentity bank;
  final double spent;
  final double received;

  /// Self-transfers, investments and settlements — real transactions, but
  /// neither spending nor income.
  final double moved;

  final int expenseCount;
  final int incomeCount;
  final int movedCount;

  const BankActivity({
    required this.bank,
    this.spent = 0,
    this.received = 0,
    this.moved = 0,
    this.expenseCount = 0,
    this.incomeCount = 0,
    this.movedCount = 0,
  });

  String get id => bank.id;
  String get name => bank.name;

  /// Every transaction seen for this bank, counted or not.
  int get transactionCount => expenseCount + incomeCount + movedCount;

  /// Average expense per spending transaction.
  double get averageSpend => expenseCount > 0 ? spent / expenseCount : 0;

  /// What this bank left behind over the period.
  double get net => received - spent;

  BankActivity _plus(TransactionModel t) {
    final isExpense = t.type == TransactionType.debit;
    final counts = isExpense
        ? ExpenseCategories.isExpenseCategory(t.category)
        : ExpenseCategories.isIncomeCategory(t.category);

    if (!counts) {
      return BankActivity(
        bank: bank,
        spent: spent,
        received: received,
        // Debits are the split-aware side; credits are never split.
        moved: moved + (isExpense ? t.effectiveAmount : t.amount),
        expenseCount: expenseCount,
        incomeCount: incomeCount,
        movedCount: movedCount + 1,
      );
    }
    return BankActivity(
      bank: bank,
      spent: spent + (isExpense ? t.effectiveAmount : 0),
      received: received + (isExpense ? 0 : t.amount),
      moved: moved,
      expenseCount: expenseCount + (isExpense ? 1 : 0),
      incomeCount: incomeCount + (isExpense ? 0 : 1),
      movedCount: movedCount,
    );
  }
}

/// Bank-wise activity for one period, built from that period's transactions.
///
/// Only banks the user actually transacted with in the period are present —
/// three accounts but one used this month means one row, and the month a
/// dormant account wakes up it appears on its own.
class BankBreakdown {
  /// Ranked: most spent first, then most received, then name.
  final List<BankActivity> banks;

  const BankBreakdown(this.banks);

  static const BankBreakdown empty = BankBreakdown([]);

  factory BankBreakdown.fromTransactions(Iterable<TransactionModel> txns) {
    final byBank = <String, BankActivity>{};
    for (final t in txns) {
      final bank = BankDirectory.resolve(t);
      byBank[bank.id] =
          (byBank[bank.id] ?? BankActivity(bank: bank))._plus(t);
    }
    final list = byBank.values.toList()
      ..sort((a, b) {
        final bySpend = b.spent.compareTo(a.spent);
        if (bySpend != 0) return bySpend;
        final byIncome = b.received.compareTo(a.received);
        if (byIncome != 0) return byIncome;
        return a.name.compareTo(b.name);
      });
    return BankBreakdown(list);
  }

  bool get isEmpty => banks.isEmpty;
  bool get isNotEmpty => banks.isNotEmpty;

  /// How many banks were used in the period.
  int get bankCount => banks.length;

  double get totalSpent => banks.fold(0.0, (sum, b) => sum + b.spent);
  double get totalReceived => banks.fold(0.0, (sum, b) => sum + b.received);
  double get totalMoved => banks.fold(0.0, (sum, b) => sum + b.moved);
  int get transactionCount =>
      banks.fold(0, (sum, b) => sum + b.transactionCount);

  /// The bank the user spent the most from, or null when nothing was spent.
  BankActivity? get topSpender {
    for (final b in banks) {
      if (b.spent > 0) return b;
    }
    return null;
  }

  /// Banks that saw any real spending, in rank order.
  List<BankActivity> get spenders =>
      banks.where((b) => b.spent > 0).toList(growable: false);

  /// [bank]'s share of the period's spending (0..1).
  double share(BankActivity bank) =>
      totalSpent > 0 ? bank.spent / totalSpent : 0;

  /// [bank]'s spend relative to the biggest spender, for bar widths (0..1).
  double barFraction(BankActivity bank) {
    final peak = topSpender?.spent ?? 0;
    return peak > 0 ? (bank.spent / peak).clamp(0.0, 1.0).toDouble() : 0;
  }

  /// The activity for [id], or null when that bank was idle this period.
  BankActivity? forId(String id) {
    for (final b in banks) {
      if (b.id == id) return b;
    }
    return null;
  }
}
