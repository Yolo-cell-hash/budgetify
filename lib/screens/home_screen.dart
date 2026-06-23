import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/database_service.dart';
import '../services/financial_health_service.dart';
import '../services/gamification_service.dart';
import '../services/sms_service.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';
import '../services/sip_service.dart';
import '../services/widget_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_preferences.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/category_icon.dart';
import '../widgets/financial_health_card.dart';
import '../widgets/glass.dart';
import '../widgets/insights_card.dart';
import '../widgets/savings_summary.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/motion.dart';
import '../widgets/permission_request_card.dart';
import '../widgets/expense_chart.dart';
import 'transactions_screen.dart';
import 'add_transaction_screen.dart';
import 'goals_screen.dart';
import 'net_worth_screen.dart';
import 'rewards_hub_screen.dart';
import 'splits_screen.dart';
import 'wrapped_screen.dart';

/// Home screen of the Budget Tracker app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SmsService _smsService = SmsService();
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  bool _hasPermission = false;
  bool _isPermanentlyDenied = false;
  bool _isLoading = true;
  bool _isScanning = false;

  int _transactionCount = 0;
  int _unclassifiedCount = 0;
  List<TransactionModel> _recentTransactions = [];
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _cashTransactions = [];
  double _totalCash = 0;
  double _monthlyIncome = 0;
  double _monthlyExpenses = 0;
  // Recurring investments due today and still unanswered (drives the alert).
  int _dueSipCount = 0;
  // Latest Financial Health Score; recomputed on every data refresh so both
  // the full card and the compact balance-card indicator stay current.
  FinancialHealth? _health;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh when data changes elsewhere (e.g. a backup restore in Settings),
    // since this tab stays alive in the IndexedStack and won't rebuild on its
    // own.
    appDataRevision.addListener(_onExternalDataChange);
    // Roll the daily-usage streak forward (drives the gamified streak badges).
    // Runs regardless of whether the mode is enabled, so it's accurate if the
    // user turns it on later. Fire-and-forget.
    GamificationService().recordActiveDay();
    _initialize();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_onExternalDataChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onExternalDataChange() {
    if (mounted) _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      GamificationService().recordActiveDay();
      _checkPermission();
      // Auto-scan and reload on resume
      _autoScanSms();
    }
  }

  Future<void> _initialize() async {
    await _notificationService.initialize();
    await _checkPermission();
    await _loadData();
    setState(() => _isLoading = false);

    // Auto-scan SMS after initial load
    if (_hasPermission) {
      await _autoScanSms();
    }
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _smsService.hasPermission();
    final isPermanentlyDenied = await _smsService
        .isPermissionPermanentlyDenied();

    setState(() {
      _hasPermission = hasPermission;
      _isPermanentlyDenied = isPermanentlyDenied;
    });

    if (hasPermission) {
      _startSmsListening();
    }
  }

  Future<void> _loadData() async {
    try {
      final transactions = await _dbService.getAllTransactions();
      final unclassified = await _dbService.getUnclassifiedTransactions();

      // Calculate month boundaries (used by cash filter and monthly calculations)
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(days: 1));

      // Load cash data (current month only)
      final allCashTxns = await _dbService.getCashTransactions();
      final cashTxns = allCashTxns.where((t) {
        return !t.detectedAt.isBefore(monthStart.subtract(const Duration(days: 1))) &&
            t.detectedAt.isBefore(monthEnd.add(const Duration(days: 1)));
      }).toList();
      final totalCash = cashTxns.fold(0.0, (sum, t) => sum + t.amount);

      // Calculate monthly income/expenses
      double monthlyIncome = 0;
      double monthlyExpenses = 0;
      for (final t in transactions) {
        if (t.detectedAt.isAfter(
              monthStart.subtract(const Duration(days: 1)),
            ) &&
            t.detectedAt.isBefore(monthEnd.add(const Duration(days: 1)))) {
          if (t.type == TransactionType.credit) {
            // Self-transfers and investment redemptions aren't real income.
            if (ExpenseCategories.isIncomeCategory(t.category)) {
              monthlyIncome += t.amount;
            }
          } else if (ExpenseCategories.isExpenseCategory(t.category)) {
            // Self transfers and investments aren't spending; a split
            // transaction counts only the user's own share.
            monthlyExpenses += t.effectiveAmount;
          }
        }
      }

      // Recurring investments due today and not yet logged.
      final dueSips = await SipService().pendingDueSips();

      // Financial Health Score — computed here so the full card and the compact
      // balance-card indicator share one result and refresh together whenever
      // any underlying data (budgets, holdings, recurring plans, transactions)
      // changes, not just on a cold start.
      final health = await FinancialHealthService().compute(
        income: monthlyIncome,
        expenses: monthlyExpenses,
      );

      setState(() {
        _transactionCount = transactions.length;
        _unclassifiedCount = unclassified.length;
        _recentTransactions = transactions.take(5).toList();
        _allTransactions = transactions;
        _cashTransactions = cashTxns;
        _totalCash = totalCash;
        _monthlyIncome = monthlyIncome;
        _monthlyExpenses = monthlyExpenses;
        _dueSipCount = dueSips.length;
        _health = health;
      });

      // Keep the home-screen widget in sync
      WidgetService.update();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _requestPermission() async {
    final status = await _smsService.requestPermission();
    await _checkPermission();

    if (status == PermissionStatus.granted) {
      _scanExistingSms();
    }
  }

  Future<void> _openSettings() async {
    await _smsService.openSettings();
  }

  void _startSmsListening() {
    _smsService.startListening(
      onTransactionDetected: (transaction) {
        _loadData();
        final isCredit = transaction.type == TransactionType.credit;
        final amount = '₹${transaction.amount.toStringAsFixed(2)}';
        showAppToast(
          context,
          message: isCredit
              ? context.l10nRead.txnCredited(amount)
              : context.l10nRead.txnDebited(amount),
          type: isCredit ? AppToastType.success : AppToastType.info,
          actionLabel: context.l10nRead.commonView,
          onAction: _openTransactionsScreen,
        );
      },
    );
  }

  Future<void> _scanExistingSms() async {
    setState(() => _isScanning = true);

    // The device's SMS provider can throw on a malformed message (some OEMs
    // hand back a null where an int is expected). Keep the read isolated so a
    // platform error never bubbles up as a scary "Error scanning SMS" — we
    // still refresh from the database and tell the user plainly.
    List<TransactionModel> transactions = const [];
    var scanFailed = false;
    try {
      transactions = await _smsService.scanExistingSms(maxCount: 50);
    } catch (e) {
      scanFailed = true;
      debugPrint('SMS scan failed: $e');
    }

    // Always refresh counts/totals and check thresholds, even if the read
    // failed — this is what makes the dashboard correct after a restore.
    try {
      await _loadData();
      await checkBudgetThresholds(_dbService, _notificationService);
    } catch (e) {
      debugPrint('Post-scan refresh failed: $e');
    }

    if (mounted) {
      showAppToast(
        context,
        message: scanFailed
            ? context.l10nRead.smsReadFailed
            : transactions.isEmpty
                ? context.l10nRead.noNewTransactions
                : context.l10nRead.foundTransactions(transactions.length),
        type: scanFailed
            ? AppToastType.warning
            : transactions.isEmpty
                ? AppToastType.info
                : AppToastType.success,
      );
      setState(() => _isScanning = false);
    }
  }

  /// Silently auto-scan SMS. On first install, show feedback.
  /// On subsequent opens, scan silently and only show feedback if new transactions found.
  Future<void> _autoScanSms() async {
    if (!_hasPermission || _isScanning) return;

    final prefs = await SharedPreferences.getInstance();
    final isFirstScan = prefs.getBool('needs_initial_scan') ?? false;

    setState(() => _isScanning = true);

    if (isFirstScan) {
      // First install: do a full scan with UI feedback
      try {
        final transactions = await BackgroundService.performForegroundScan(
          maxCount: 200,
        );
        await _loadData();

        // Check budget thresholds
        await checkBudgetThresholds(_dbService, _notificationService);

        // Clear the first-scan flag
        await prefs.setBool('needs_initial_scan', false);

        if (mounted && transactions.isNotEmpty) {
          showAppToast(
            context,
            message:
                context.l10nRead.foundTransactionsFromSms(transactions.length),
            type: AppToastType.success,
            actionLabel: context.l10nRead.commonView,
            onAction: _openTransactionsScreen,
          );
        }
      } catch (e) {
        // Silently fail on auto-scan
      } finally {
        if (mounted) setState(() => _isScanning = false);
      }
    } else {
      // Subsequent opens: silent scan in background
      try {
        final transactions = await BackgroundService.performForegroundScan(
          maxCount: 100,
        );

        if (transactions.isNotEmpty) {
          await _loadData();

          // Check budget thresholds
          await checkBudgetThresholds(_dbService, _notificationService);

          if (mounted) {
            showAppToast(
              context,
              message:
                  context.l10nRead.newTransactionsFound(transactions.length),
              type: AppToastType.success,
            );
          }
        } else {
          // Still reload data from DB even if no new SMS transactions
          await _loadData();
          // Still check budget thresholds
          await checkBudgetThresholds(_dbService, _notificationService);
        }
      } catch (e) {
        // Silently fail on auto-scan, but still load from DB
        await _loadData();
      } finally {
        if (mounted) setState(() => _isScanning = false);
      }
    }
  }

  void _openTransactionsScreen({bool unclassifiedOnly = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionsScreen(
          initialUnclassifiedOnly: unclassifiedOnly,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openMonthlyTransactions(TransactionType type) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(
          initialTypeFilter: type,
          initialStartDate: monthStart,
          initialEndDate: monthEnd,
        ),
      ),
    ).then((_) => _loadData());
  }

  /// Themed "exit app?" confirmation shown on a root back press.
  Future<void> _confirmExit() async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.logout_rounded,
        title: context.l10nRead.exitTitle,
        subtitle: context.l10nRead.exitSubtitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10nRead.stay),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10nRead.exit),
          ),
        ],
      ),
    );
    if (ok == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // When on, show the full Financial Health breakdown card; when off, a
    // compact score indicator rides on the balance card instead.
    final detailed = context.watch<AppPreferences>().financialHealthDetailed;
    return PopScope(
      // Intercept the root back press so we can confirm before exiting.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(order: 0, child: _buildHeader()),

                        if (!_hasPermission)
                          FadeSlideIn(
                            order: 1,
                            child: PermissionRequestCard(
                              onRequestPermission: _requestPermission,
                              onOpenSettings: _openSettings,
                              isPermanentlyDenied: _isPermanentlyDenied,
                            ),
                          )
                        else ...[
                          // Uniform 12px rhythm between every dashboard card;
                          // cards carry horizontal margin only so spacing is
                          // controlled here in one place.
                          const SizedBox(height: 4),
                          FadeSlideIn(
                            order: 1,
                            child:
                                _buildBalanceCard(showHealthInline: !detailed),
                          ),
                          // Full Financial Health breakdown card — only in the
                          // detailed view; otherwise the compact score sits on
                          // the balance card's savings-rate area above.
                          if (detailed && _health != null) ...[
                            const SizedBox(height: 12),
                            FadeSlideIn(
                              order: 2,
                              child: FinancialHealthCard(health: _health!),
                            ),
                          ],
                          if (_dueSipCount > 0) ...[
                            const SizedBox(height: 12),
                            FadeSlideIn(order: 3, child: _buildSipAlert()),
                          ],
                          // Gated behind AI Prediction Mode — when off, nothing
                          // here is built and the dashboard is unchanged.
                          if (context
                              .watch<AppPreferences>()
                              .aiPredictionMode) ...[
                            const SizedBox(height: 12),
                            FadeSlideIn(
                              order: 2,
                              child: InsightsCard(
                                reloadToken: _transactionCount,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          FadeSlideIn(
                            order: 3,
                            child: ExpenseChartWidget(
                              transactions: _allTransactions,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FadeSlideIn(order: 4, child: _buildCashSection()),
                          const SizedBox(height: 12),
                          FadeSlideIn(order: 5, child: const HomeGoalsCard()),
                          const SizedBox(height: 12),
                          FadeSlideIn(order: 5, child: _buildWrappedEntry()),
                          const SizedBox(height: 12),
                          FadeSlideIn(order: 6, child: _buildSplitsEntry()),
                          const SizedBox(height: 12),
                          FadeSlideIn(order: 7, child: _buildQuickActions()),
                          const SizedBox(height: 12),
                          FadeSlideIn(
                            order: 8,
                            child: _buildRecentTransactions(),
                          ),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  /// Alert shown on the dashboard when a recurring investment is due today and
  /// hasn't been answered via the notification. Leads to the Net Worth review.
  Widget _buildSipAlert() {
    final n = _dueSipCount;
    final hero = HeroStyle.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NetWorthScreen(reviewSips: true),
              ),
            );
            await _loadData();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: hero.gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hero.border),
              boxShadow: hero.shadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Text('🔔', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.investmentAlert,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: hero.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.investmentsToConfirm(n),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: hero.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: hero.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budgetify',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.fullDate(DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: -0.1,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasPermission)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.success.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: colors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.smsActive,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Quick reveal/hide toggle, shown only when privacy mode is on
              if (context.watch<AppPreferences>().privacyMode)
                IconButton(
                  icon: Icon(
                    context.watch<AppPreferences>().amountsHidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: colors.textSecondary,
                  ),
                  tooltip: context.l10n.showHideAmounts,
                  onPressed: () =>
                      context.read<AppPreferences>().toggleReveal(),
                ),
              // Gamified Budgets entry point — opens the Rewards hub. Only
              // shown when the mode is enabled; the dashboard is otherwise
              // untouched.
              if (context.watch<AppPreferences>().gamifiedMode) ...[
                const SizedBox(width: 4),
                const HomeRewardsAvatar(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({bool showHealthInline = false}) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final colors = AppColors.of(context);
    final hero = HeroStyle.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: hero.gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hero.border),
        boxShadow: hero.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.monthExpenses(DateTime.now().month),
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: hero.accent,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hero.innerFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hero.innerBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 13,
                      color: hero.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.spent,
                      style: TextStyle(
                        fontSize: 11,
                        color: hero.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrivacyAnimatedAmount(
            value: _monthlyExpenses,
            formatter: formatter,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: hero.foreground,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hero.innerFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hero.innerBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openMonthlyTransactions(TransactionType.credit),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.success.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(
                                Icons.arrow_downward,
                                size: 12,
                                color: colors.success,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.commonIncome,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                color: hero.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        PrivacyAmount(
                          formatter.format(_monthlyIncome),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: hero.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: hero.divider,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openMonthlyTransactions(TransactionType.debit),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              context.l10n.commonExpenses,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                color: hero.mutedForeground,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.danger.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(
                                Icons.arrow_upward,
                                size: 12,
                                color: colors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        PrivacyAmount(
                          formatter.format(_monthlyExpenses),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: hero.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SavingsRateBar(
            income: _monthlyIncome,
            expenses: _monthlyExpenses,
            onDark: hero.onDark,
          ),
          // Compact Financial Health indicator, shown here under the savings
          // rate when the detailed card is turned off.
          if (showHealthInline && (_health?.hasScore ?? false)) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: hero.divider),
            const SizedBox(height: 14),
            FinancialHealthInline(health: _health!, onDark: hero.onDark),
          ],
        ],
      ),
    );
  }

  Widget _buildWrappedEntry() {
    final hero = HeroStyle.of(context);

    return PressableScale(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WrappedScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [AppColors.goldDeep, AppColors.gold, AppColors.goldDeep],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: hero.shadow,
        ),
        padding: const EdgeInsets.all(1.4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: hero.gradient,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.22),
                      AppColors.gold.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.30),
                  ),
                ),
                child: const Center(
                  child: Text('✨', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.monthWrapped(DateTime.now().month),
                      style: TextStyle(
                        color: hero.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.wrappedSubtitle,
                      style: TextStyle(
                        color: hero.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hero.innerFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: hero.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSplitsEntry() {
    final colors = AppColors.of(context);

    return PressableScale(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SplitsScreen()),
        );
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.call_split_rounded,
                    color: AppColors.goldDeep, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.splits,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.splitsSubtitle,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.receipt_long_outlined,
              label: context.l10n.transactions,
              value: _transactionCount.toString(),
              color: colors.accent,
              onTap: _openTransactionsScreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.pending_actions_outlined,
              label: context.l10n.unclassified,
              value: _unclassifiedCount.toString(),
              color: AppColors.goldDeep,
              onTap: () => _openTransactionsScreen(unclassifiedOnly: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.sync,
              label: context.l10n.scanSms,
              value: _isScanning ? '...' : context.l10n.scan,
              color: colors.success,
              onTap: _isScanning ? null : _scanExistingSms,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final colors = AppColors.of(context);

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.1,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_recentTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = AppColors.of(context);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormatter = DateFormat('MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.recentTransactions,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: colors.text,
                ),
              ),
              TextButton(
                onPressed: _openTransactionsScreen,
                child: Text(context.l10n.commonSeeAll),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _recentTransactions.asMap().entries.map((entry) {
              final index = entry.key;
              final transaction = entry.value;
              final isCredit = transaction.type == TransactionType.credit;
              final isLast = index == _recentTransactions.length - 1;

              return Column(
                children: [
                  ListTile(
                    leading: TransactionLeadingIcon(
                      transaction: transaction,
                      size: 42,
                    ),
                    title: Text(
                      transaction.category != null
                          ? context.l10n.categoryName(transaction.category!)
                          : transaction.sender,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: -0.1,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      dateFormatter.format(transaction.detectedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                    trailing: PrivacyAmount(
                      '${isCredit ? '+' : '-'} ${formatter.format(transaction.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: isCredit ? colors.success : colors.danger,
                      ),
                    ),
                    onTap: _openTransactionsScreen,
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 16,
                      color: colors.border,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCashSection() {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final conversions = _cashTransactions
        .where((t) => t.category == 'Cash Conversion')
        .length;

    // Cash keeps its own "money green" identity, but adapts: a deep forest
    // gradient on dark, a fresh light-mint card on light — so it feels native
    // to each theme rather than a dark block on a porcelain dashboard.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cashGradient = isDark
        ? const [Color(0xFF1E4636), Color(0xFF12291F)]
        : const [Color(0xFFEAF7EF), Color(0xFFD3EBDD)];
    final cashFg = isDark ? Colors.white : const Color(0xFF134E33);
    final cashMuted =
        isDark ? Colors.white : const Color(0xFF2E6B4D);
    final cashBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF1E8A5A).withValues(alpha: 0.22);
    final cashIconBg = isDark
        ? Colors.white.withAlpha(50)
        : Colors.white.withValues(alpha: 0.7);
    final convChipBg = isDark
        ? AppColors.gold.withOpacity(0.22)
        : AppColors.goldDeep.withValues(alpha: 0.14);

    return PressableScale(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AddTransactionScreen(initialCategory: 'Cash Conversion'),
          ),
        );
        if (result == true) _loadData();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cashGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cashBorder),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF1E8A5A).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cashIconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('💵', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.cashTransactions,
                    style: TextStyle(
                      color: cashFg,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PrivacyAmount(
                  fmt.format(_totalCash),
                  style: TextStyle(
                    color: cashFg,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (conversions > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: convChipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💱', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.cashConversions(conversions),
                      style: TextStyle(color: cashMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
