import '../models/holding.dart';
import '../models/monthly_recap.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

/// Builds a privacy-safe [MonthlyRecap] for a given month from on-device data.
/// Pure statistics over the local database — no network, no amounts leave the
/// device (the recap itself carries only percentages, counts and names).
class RecapService {
  final DatabaseService _db;

  RecapService([DatabaseService? db]) : _db = db ?? DatabaseService();

  // Ignore tiny-base categories when picking the month's biggest mover.
  static const double _minMoverBase = 500;

  Future<MonthlyRecap> compute(DateTime month, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final txns = await _db.getTransactionsByDateRange(monthStart, monthEnd);
    final availableDays =
        MonthlyRecap.availableDaysFor(txns.map((t) => t.detectedAt));
    final spent =
        await _db.getSpendingForPeriod(startDate: monthStart, endDate: monthEnd);
    final hasData = spent > 0;

    // Gate: not enough of the month recorded yet.
    if (availableDays < MonthlyRecap.minDays || !hasData) {
      return MonthlyRecap.insufficient(monthStart, availableDays);
    }

    // True income (excludes self-transfers / investment redemptions).
    double income = 0;
    for (final t in txns) {
      if (t.type == TransactionType.credit &&
          ExpenseCategories.isIncomeCategory(t.category)) {
        income += t.amount;
      }
    }
    final savingsRatePct = MonthlyRecap.pct(income - spent, income);

    // Biggest single expense of the month (for the reveal-numbers view).
    double? biggestTxnAmount;
    String? biggestTxnLabel;
    for (final t in txns) {
      if (t.type == TransactionType.debit &&
          ExpenseCategories.isExpenseCategory(t.category)) {
        if (biggestTxnAmount == null || t.amount > biggestTxnAmount) {
          biggestTxnAmount = t.amount;
          biggestTxnLabel = t.merchantName ?? t.category ?? t.sender;
        }
      }
    }
    final avgPerDay = availableDays > 0 ? spent / availableDays : 0.0;

    // Spend vs last month.
    final lastStart = DateTime(month.year, month.month - 1, 1);
    final lastEnd = DateTime(month.year, month.month, 0, 23, 59, 59);
    final spentLast =
        await _db.getSpendingForPeriod(startDate: lastStart, endDate: lastEnd);
    final spendVsLastMonthPct =
        spentLast > 0 ? ((spent - spentLast) / spentLast * 100).round() : null;

    // Top category + biggest mover vs last month.
    final byCat =
        await _db.getSpendingByCategory(startDate: monthStart, endDate: monthEnd);
    final catLast =
        await _db.getSpendingByCategory(startDate: lastStart, endDate: lastEnd);

    RecapHighlight? topCategory;
    double? topCategoryAmount;
    if (byCat.isNotEmpty) {
      final top = byCat.entries.first; // query is ordered desc
      topCategoryAmount = top.value;
      topCategory = RecapHighlight(
        label: top.key,
        icon: ExpenseCategories.getIcon(top.key),
        sharePct: MonthlyRecap.pct(top.value, spent) ?? 0,
      );
    }

    ({String cat, double change, double pct})? best;
    for (final e in byCat.entries) {
      final prev = catLast[e.key] ?? 0;
      if (prev < _minMoverBase) continue;
      final change = e.value - prev;
      if (change.abs() < _minMoverBase * 0.4) continue;
      if (best == null || change.abs() > best.change.abs()) {
        best = (cat: e.key, change: change, pct: change / prev * 100);
      }
    }
    final mover = best == null
        ? null
        : RecapMover(
            label: best.cat,
            icon: ExpenseCategories.getIcon(best.cat),
            changePct: best.pct.round(),
          );

    // Top merchant + distinct merchant count.
    final merchants = await _db.getMerchantBreakdown(
        startDate: monthStart, endDate: monthEnd);
    RecapHighlight? topMerchant;
    double? topMerchantAmount;
    if (merchants.isNotEmpty) {
      final m = merchants.first;
      topMerchantAmount = (m['total'] as num).toDouble();
      topMerchant = RecapHighlight(
        label: m['merchant'] as String,
        icon: '🏪',
        sharePct: MonthlyRecap.pct(topMerchantAmount, spent) ?? 0,
      );
    }

    // Net worth: snapshot the live month, then compare to the previous month.
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    if (isCurrentMonth) {
      await _db.recordNetWorthSnapshotForCurrentMonth();
    }
    String periodKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}';
    final curNw = await _db.getNetWorthSnapshot(periodKey(monthStart));
    final prevNw = await _db.getNetWorthSnapshot(periodKey(lastStart));
    int? netWorthChangePct;
    if (curNw != null && prevNw != null && prevNw.abs() > 0) {
      netWorthChangePct = ((curNw - prevNw) / prevNw.abs() * 100).round();
    }

    // Fallback wealth stat: investments as a share of assets.
    final summary = NetWorthSummary(await _db.getHoldings());
    final investedPct = summary.assets > 0
        ? (summary.investments / summary.assets * 100).round()
        : null;

    return MonthlyRecap(
      month: monthStart,
      availableDays: availableDays,
      hasData: true,
      savingsRatePct: savingsRatePct,
      spendVsLastMonthPct: spendVsLastMonthPct,
      topCategory: topCategory,
      topMerchant: topMerchant,
      categoryMover: mover,
      netWorthChangePct: netWorthChangePct,
      investedPct: investedPct,
      transactionCount: txns.length,
      merchantCount: merchants.length,
      totalSpent: spent,
      totalIncome: income,
      topCategoryAmount: topCategoryAmount,
      topMerchantAmount: topMerchantAmount,
      categoryMoverAmount: best?.change,
      avgPerDay: avgPerDay,
      biggestTxnAmount: biggestTxnAmount,
      biggestTxnLabel: biggestTxnLabel,
    );
  }
}
