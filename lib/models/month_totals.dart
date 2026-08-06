import 'transaction_model.dart';

/// The month's headline figures for the dashboard hero: what came in, what
/// went out, and how much of what went out the parser wasn't sure about.
///
/// Derived in one pass so the three numbers can't disagree. That matters most
/// for [unconfirmedExpenses], which is displayed *underneath* [expenses] as a
/// caveat on it — computing it from a separate query, with its own filters,
/// is how you end up telling someone that ₹10,240 of a ₹5,000 total needs
/// checking. Here it is a subset of [expenses] by construction: the same
/// branch, the same category rule, the same split share.
class MonthTotals {
  /// Credits that are real income (self-transfers and investment redemptions
  /// are money moving between the user's own pockets, and are excluded).
  final double income;

  /// Debits that are real spending, counting only the user's own share of a
  /// split transaction.
  final double expenses;

  /// The part of [expenses] contributed by rows the parser flagged for a
  /// human glance. Always `<= expenses`.
  final double unconfirmedExpenses;

  const MonthTotals({
    required this.income,
    required this.expenses,
    required this.unconfirmedExpenses,
  });

  static const MonthTotals empty =
      MonthTotals(income: 0, expenses: 0, unconfirmedExpenses: 0);

  /// Fold [txns] — already narrowed to the period of interest — into totals.
  factory MonthTotals.fromTransactions(Iterable<TransactionModel> txns) {
    var income = 0.0;
    var expenses = 0.0;
    var unconfirmed = 0.0;
    for (final t in txns) {
      if (t.type == TransactionType.credit) {
        if (ExpenseCategories.isIncomeCategory(t.category)) {
          income += t.amount;
        }
      } else if (ExpenseCategories.isExpenseCategory(t.category)) {
        expenses += t.effectiveAmount;
        if (t.needsReview) unconfirmed += t.effectiveAmount;
      }
    }
    return MonthTotals(
      income: income,
      expenses: expenses,
      unconfirmedExpenses: unconfirmed,
    );
  }
}
