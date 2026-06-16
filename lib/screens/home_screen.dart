import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/sms_service.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';
import '../services/widget_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_preferences.dart';
import '../widgets/app_toast.dart';
import '../widgets/category_icon.dart';
import '../widgets/glass.dart';
import '../widgets/insights_card.dart';
import '../widgets/savings_summary.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/motion.dart';
import '../widgets/permission_request_card.dart';
import '../widgets/expense_chart.dart';
import 'transactions_screen.dart';
import 'add_transaction_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
            // Self transfers and investments aren't spending
            monthlyExpenses += t.amount;
          }
        }
      }

      setState(() {
        _transactionCount = transactions.length;
        _unclassifiedCount = unclassified.length;
        _recentTransactions = transactions.take(5).toList();
        _allTransactions = transactions;
        _cashTransactions = cashTxns;
        _totalCash = totalCash;
        _monthlyIncome = monthlyIncome;
        _monthlyExpenses = monthlyExpenses;
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
        showAppToast(
          context,
          message:
              '${isCredit ? "Credited" : "Debited"}: ₹${transaction.amount.toStringAsFixed(2)}',
          type: isCredit ? AppToastType.success : AppToastType.info,
          actionLabel: 'View',
          onAction: _openTransactionsScreen,
        );
      },
    );
  }

  Future<void> _scanExistingSms() async {
    setState(() => _isScanning = true);

    try {
      final transactions = await _smsService.scanExistingSms(maxCount: 50);
      await _loadData();

      // Check budget thresholds after scan
      await checkBudgetThresholds(_dbService, _notificationService);

      if (mounted) {
        showAppToast(
          context,
          message: transactions.isEmpty
              ? 'No new transactions found'
              : 'Found ${transactions.length} transaction${transactions.length == 1 ? '' : 's'}',
          type: transactions.isEmpty
              ? AppToastType.info
              : AppToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: 'Error scanning SMS: $e', type: AppToastType.error);
      }
    } finally {
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
                'Found ${transactions.length} transactions from your SMS',
            type: AppToastType.success,
            actionLabel: 'View',
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
                  '${transactions.length} new transaction${transactions.length > 1 ? 's' : ''} found',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          FadeSlideIn(order: 1, child: _buildBalanceCard()),
                          const SizedBox(height: 16),
                          // Gated behind AI Prediction Mode — when off, nothing
                          // here is built and the dashboard is unchanged.
                          if (context.watch<AppPreferences>().aiPredictionMode)
                            FadeSlideIn(
                              order: 2,
                              child: InsightsCard(
                                reloadToken: _transactionCount,
                              ),
                            ),
                          FadeSlideIn(
                            order: 2,
                            child: ExpenseChartWidget(
                              transactions: _allTransactions,
                            ),
                          ),
                          FadeSlideIn(order: 3, child: _buildCashSection()),
                          FadeSlideIn(order: 4, child: _buildQuickActions()),
                          FadeSlideIn(
                            order: 5,
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
                      'Budget Tracker',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
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
                        'SMS Active',
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
                  tooltip: 'Show/hide amounts',
                  onPressed: () =>
                      context.read<AppPreferences>().toggleReveal(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final monthName = DateFormat('MMMM').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName Expenses'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Spent',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
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
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                                color: AppColors.successDark.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(
                                Icons.arrow_downward,
                                size: 12,
                                color: AppColors.successDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Income',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        PrivacyAmount(
                          formatter.format(_monthlyIncome),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.12),
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
                              'Expenses',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.dangerDark.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(
                                Icons.arrow_upward,
                                size: 12,
                                color: AppColors.dangerDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        PrivacyAmount(
                          formatter.format(_monthlyExpenses),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: Colors.white,
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
            onDark: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.receipt_long_outlined,
              label: 'Transactions',
              value: _transactionCount.toString(),
              color: colors.accent,
              onTap: _openTransactionsScreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.pending_actions_outlined,
              label: 'Unclassified',
              value: _unclassifiedCount.toString(),
              color: AppColors.goldDeep,
              onTap: () => _openTransactionsScreen(unclassifiedOnly: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.sync,
              label: 'Scan SMS',
              value: _isScanning ? '...' : 'Scan',
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
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: colors.text,
                ),
              ),
              TextButton(
                onPressed: _openTransactionsScreen,
                child: const Text('See All'),
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
                      transaction.category ?? transaction.sender,
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E4636), Color(0xFF12291F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('💵', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cash Transactions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PrivacyAmount(
                  fmt.format(_totalCash),
                  style: const TextStyle(
                    color: Colors.white,
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
                  color: AppColors.gold.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💱', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '$conversions Cash Conversion${conversions > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
