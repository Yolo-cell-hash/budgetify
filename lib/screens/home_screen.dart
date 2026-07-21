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
import '../services/dev_mode.dart';
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
import '../widgets/hero_aura.dart';
import '../widgets/insights_card.dart';
import '../widgets/savings_summary.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/royal_reactions.dart';
import '../widgets/upcoming_recurring_card.dart';
import '../widgets/motion.dart';
import '../widgets/permission_request_card.dart';
import '../widgets/expense_chart.dart';
import '../services/tutorial_service.dart';
import '../widgets/spotlight.dart';
import '../widgets/streak_save_sheet.dart';
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

  // Anchors the Gamified Budgets spotlight to the Rewards avatar in the
  // header.
  final GlobalKey _rewardsAvatarKey = GlobalKey();

  // Guided-tour anchors on this dashboard.
  final GlobalKey _firstRecentTxnKey = GlobalKey();
  final GlobalKey _balanceCardKey = GlobalKey();
  final GlobalKey _goalsCardKey = GlobalKey();

  // Spotlight anchors for features enabled from Settings (the toggle sends
  // the user here to see what appeared).
  final GlobalKey _insightsCardKey = GlobalKey();
  final GlobalKey _healthCardKey = GlobalKey();

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
    // user turns it on later. Fire-and-forget; may surface the Streak Save
    // sheet if the roll just broke a saveable streak.
    _rollStreak();
    // Settings requests a spotlight here right after Gamified Budgets is
    // switched on (it also switches the shell back to this tab).
    homeSpotlightRequest.addListener(_onSpotlightRequest);
    // Guided tour: load saved progress, then re-evaluate the current tip
    // whenever the step moves or this tab becomes visible again.
    TutorialService.instance.load();
    TutorialService.instance.addListener(_onTutorialTick);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowTutorialTip());
    _initialize();
  }

  @override
  void dispose() {
    TutorialService.instance.removeListener(_onTutorialTick);
    homeSpotlightRequest.removeListener(_onSpotlightRequest);
    appDataRevision.removeListener(_onExternalDataChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onExternalDataChange() {
    if (mounted) _loadData();
  }

  void _onTutorialTick() {
    if (mounted) _maybeShowTutorialTip();
  }

  /// Drives the guided tour's Home-anchored steps. Tips only appear while
  /// Home is the visible tab with no route pushed above it. Action steps pass
  /// the tap through to the real control; info steps advance via their own
  /// Next button.
  void _maybeShowTutorialTip() {
    if (!mounted || _isLoading) return;
    if (mainShellTabIndex.value != 0) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final l10n = context.l10nRead;
    final svc = TutorialService.instance;
    switch (svc.step) {
      case TutorialStep.viewTransactions:
        // Waits silently until the first scanned (or manual) transaction
        // exists — the tour starts from something real.
        if (_recentTransactions.isEmpty) return;
        TutorialTips.show(
          context,
          step: TutorialStep.viewTransactions,
          anchor: _firstRecentTxnKey,
          title: l10n.tutViewTxnsTitle,
          message: l10n.tutViewTxnsBody,
        );
      case TutorialStep.health:
        TutorialTips.show(
          context,
          step: TutorialStep.health,
          anchor: _balanceCardKey,
          title: l10n.tutHealthTitle,
          message: l10n.tutHealthBody,
          passthrough: false,
          buttonLabel: l10n.tutNext,
          onButton: () => svc.advanceFrom(TutorialStep.health),
          advanceIfMissing: true,
        );
      case TutorialStep.goals:
        TutorialTips.show(
          context,
          step: TutorialStep.goals,
          anchor: _goalsCardKey,
          title: l10n.tutGoalsTitle,
          message: l10n.tutGoalsBody,
          passthrough: false,
          buttonLabel: l10n.tutNext,
          onButton: () => svc.advanceFrom(TutorialStep.goals),
          advanceIfMissing: true,
        );
      // The "tap this tab" steps (Budgets → Recurring → Net Worth → Settings)
      // are anchored on the bottom bar and shown by MainShell; each section
      // then presents its own intro tip in place.
      default:
        break;
    }
  }

  /// Settings sends the user Home right after enabling a feature there
  /// (Gamified Budgets, AI Prediction Mode, Detailed Financial Health) and
  /// asks for a spotlight on the thing that just appeared.
  void _onSpotlightRequest() {
    final request = homeSpotlightRequest.value;
    if (request == null) return;
    homeSpotlightRequest.value = null;
    final l10n = context.l10nRead;
    switch (request) {
      case 'rewards':
        _spotlightHomeTarget(
          _rewardsAvatarKey,
          l10n.rewardsSpotlightTitle,
          l10n.rewardsSpotlightBody,
          shape: SpotlightShape.circle,
        );
      case 'insights':
        _spotlightHomeTarget(
          _insightsCardKey,
          l10n.insightsSpotlightTitle,
          l10n.insightsSpotlightBody,
        );
      case 'health':
        _spotlightHomeTarget(
          _healthCardKey,
          l10n.healthSpotlightTitle,
          l10n.healthSpotlightBody,
        );
    }
  }

  /// Waits for the target to be mounted and laid out (the dashboard rebuilds
  /// right after the toggle flips and the shell switches tabs), scrolls it
  /// into view, then spotlights it.
  Future<void> _spotlightHomeTarget(
    GlobalKey targetKey,
    String title,
    String message, {
    SpotlightShape shape = SpotlightShape.rrect,
  }) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      final targetContext = targetKey.currentContext;
      final box = targetContext?.findRenderObject() as RenderBox?;
      if (targetContext == null ||
          box == null ||
          !box.attached ||
          !box.hasSize) {
        continue;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 260),
        alignment: 0.1,
      );
      if (!mounted) return;
      await showSpotlight(
        context,
        targetKey: targetKey,
        title: title,
        message: message,
        buttonLabel: context.l10nRead.gotIt,
        shape: shape,
      );
      return;
    }
  }

  /// Advance the daily streak, then — if that just revealed a saveable break
  /// (one missed day, a freeze banked) — offer the Streak Save once. The offer
  /// stays reachable all day from the Streak Rewards screen either way.
  Future<void> _rollStreak() async {
    final svc = GamificationService();
    await svc.recordActiveDay();
    final offer = await svc.popStreakSavePrompt();
    if (offer == null || !mounted) return;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _offerStreakSave(offer));
  }

  Future<void> _offerStreakSave(({int previous, int freezes}) offer) async {
    if (!mounted) return;
    final restored = await showStreakSaveSheet(
      context,
      previous: offer.previous,
      available: offer.freezes,
    );
    if (restored == null || !mounted) return;
    showAppToast(
      context,
      message: context.l10nRead.streakRestoredToast(restored),
      type: AppToastType.success,
    );
    notifyAppDataChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rollStreak();
      _checkPermission();
      // Auto-scan and reload on resume
      _autoScanSms();
    }
  }

  Future<void> _initialize() async {
    await _notificationService.initialize();
    await _checkPermission();
    await _loadData();
    if (!mounted) return;
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
    if (!mounted) return;

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

      // Month window as a half-open interval [monthStart, nextMonthStart):
      // everything from the 1st at 00:00 up to — but not including — the 1st of
      // next month. The earlier code padded both bounds by ±1 day, which leaked
      // the previous month's last day into the current month (e.g. a June 30
      // spend showing under July's total on the 1st). Used by the cash filter
      // and the monthly income/expense totals.
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonthStart = DateTime(now.year, now.month + 1, 1);
      bool inThisMonth(DateTime d) =>
          !d.isBefore(monthStart) && d.isBefore(nextMonthStart);

      // Load cash data (current month only)
      final allCashTxns = await _dbService.getCashTransactions();
      final cashTxns =
          allCashTxns.where((t) => inThisMonth(t.detectedAt)).toList();
      final totalCash = cashTxns.fold(0.0, (sum, t) => sum + t.amount);

      // Calculate monthly income/expenses
      double monthlyIncome = 0;
      double monthlyExpenses = 0;
      for (final t in transactions) {
        if (inThisMonth(t.detectedAt)) {
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

      // Cosmetic only: let an equipped royal react to a freshly over-budget or
      // newly-healthy state (a no-op unless a royal is equipped). Never blocks.
      RoyalMood.observe(health);

      // Keep the home-screen widget in sync
      WidgetService.update();

      // A data refresh can satisfy the tour's current step (e.g. the first
      // scanned transaction just arrived, or the user just popped back from
      // the tag flow) — re-broadcast so every tip owner re-evaluates.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => TutorialService.instance.poke());
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
    if (!mounted) return;

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
                            child: KeyedSubtree(
                              key: _balanceCardKey,
                              child: _buildBalanceCard(
                                  showHealthInline: !detailed),
                            ),
                          ),
                          // Full Financial Health breakdown card — only in the
                          // detailed view; otherwise the compact score sits on
                          // the balance card's savings-rate area above.
                          if (detailed && _health != null) ...[
                            const SizedBox(height: 12),
                            FadeSlideIn(
                              order: 2,
                              child: KeyedSubtree(
                                key: _healthCardKey,
                                child:
                                    FinancialHealthCard(health: _health!),
                              ),
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
                              child: KeyedSubtree(
                                key: _insightsCardKey,
                                child: InsightsCard(
                                  reloadToken: _transactionCount,
                                ),
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
                          FadeSlideIn(
                            order: 5,
                            child: KeyedSubtree(
                              key: _goalsCardKey,
                              child: const HomeGoalsCard(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FadeSlideIn(
                              order: 5, child: const UpcomingRecurringCard()),
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
                    color: hero.accent.withValues(alpha: 0.16),
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
                    // Five quick taps on the wordmark opens the hidden
                    // developer-mode gate (see DevMode).
                    DevModeGate(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                          ValueListenableBuilder<bool>(
                            valueListenable: DevMode.active,
                            builder: (_, devOn, __) => devOn
                                ? Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.accent
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: colors.accent
                                              .withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      'DEV',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: colors.accent,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
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
                KeyedSubtree(
                  key: _rewardsAvatarKey,
                  child: const HomeRewardsAvatar(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({bool showHealthInline = false}) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final hero = HeroStyle.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: hero.gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hero.border),
        boxShadow: hero.shadow,
      ),
      child: Stack(
        children: [
          if (hero.showAura) HeroAura(color: hero.accent),
          Padding(
            padding: const EdgeInsets.all(24),
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
                                color: hero.positive.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(
                                Icons.arrow_downward,
                                size: 12,
                                color: hero.positive,
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
                                color: hero.negative.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(
                                Icons.arrow_upward,
                                size: 12,
                                color: hero.negative,
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
          ),
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
          gradient: LinearGradient(
            colors: [
              AppColors.of(context).brandAccentDeep,
              AppColors.of(context).brandAccent,
              AppColors.of(context).brandAccentDeep,
            ],
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
                      hero.accent.withValues(alpha: 0.22),
                      hero.accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hero.accent.withValues(alpha: 0.30),
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
                color: colors.brandAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.call_split_rounded,
                    color: colors.brandAccent, size: 22),
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
              color: colors.brandAccent,
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
                    // Tour anchor: the first row is what the "a transaction
                    // just landed" tip points at.
                    key: index == 0 ? _firstRecentTxnKey : null,
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
    final convChipBg =
        AppColors.of(context).brandAccent.withOpacity(isDark ? 0.22 : 0.14);

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
