import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/transaction_model.dart';
import '../screens/transactions_screen.dart';
import '../screens/net_worth_screen.dart';
import 'package:intl/intl.dart';

/// Service for showing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Root navigator key so a tapped notification can open a screen.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Payload that routes to the unclassified-transactions list.
  static const String openUnclassifiedPayload = 'open_unclassified';

  /// Payload that routes to the Net Worth tab to confirm a due SIP/RD.
  static const String openSipReviewPayload = 'open_sip_review';

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'transaction_channel',
        'Transaction Alerts',
        description: 'Notifications for detected bank transactions',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'budget_channel',
        'Budget Alerts',
        description: 'Notifications for budget thresholds',
        importance: Importance.max,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'sip_channel',
        'SIP & RD Reminders',
        description: 'Reminders to log your recurring investments',
        importance: Importance.high,
      ),
    );

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    _routeForPayload(response.payload);
  }

  /// If the app was cold-started by tapping a notification, route to the
  /// right screen once the first frame (and navigator) is ready.
  Future<void> handleLaunchPayload() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details!.notificationResponse?.payload;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routeForPayload(payload),
      );
    }
  }

  void _routeForPayload(String? payload) {
    if (payload == openUnclassifiedPayload) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
              const TransactionsScreen(initialUnclassifiedOnly: true),
        ),
      );
    } else if (payload == openSipReviewPayload) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const NetWorthScreen(reviewSips: true),
        ),
      );
    }
  }

  Future<void> showTransactionNotification(TransactionModel transaction) async {
    if (!_isInitialized) await initialize();

    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final amountStr = formatter.format(transaction.amount);
    final isCredit = transaction.type == TransactionType.credit;

    await _notifications.show(
      transaction.detectedAt.millisecondsSinceEpoch ~/ 1000,
      isCredit ? '💰 Money Credited' : '💸 Money Debited',
      '$amountStr ${isCredit ? 'received' : 'spent'}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'transaction_channel',
          'Transaction Alerts',
          channelDescription: 'Notifications for detected bank transactions',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      payload: transaction.id?.toString(),
    );
  }

  /// Show budget threshold notification for any percentage threshold.
  /// Supports 50, 75, 90, 100, 120, 150, 200, 250, 300, ...
  ///
  /// When [category] is set, the alert is scoped to a per-category budget:
  /// the title names the category and [notificationId] keeps each category's
  /// alert in its own slot (so a Food alert never overwrites a Shopping one).
  Future<void> showBudgetNotification({
    required int threshold,
    required double spent,
    required double budget,
    String? category,
    int? notificationId,
  }) async {
    if (!_isInitialized) await initialize();

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    String title;
    String body;
    String emoji;

    if (threshold <= 50) {
      emoji = '⚠️';
      title = '$emoji 50% Budget Used';
      body =
          'You\'ve spent ${fmt.format(spent)} of your ${fmt.format(budget)} budget. Stay on track!';
    } else if (threshold <= 75) {
      emoji = '🔶';
      title = '$emoji 75% Budget Used';
      body =
          'Spent ${fmt.format(spent)} of ${fmt.format(budget)}. Only ${fmt.format(budget - spent)} left!';
    } else if (threshold <= 90) {
      emoji = '🟠';
      title = '$emoji 90% Budget Used';
      body =
          'Spent ${fmt.format(spent)} of ${fmt.format(budget)}. You\'re approaching your limit!';
    } else if (threshold <= 100) {
      emoji = '🚨';
      title = '$emoji Budget Limit Reached!';
      body =
          'You\'ve hit ${fmt.format(budget)}. Total spent: ${fmt.format(spent)}.';
    } else if (threshold <= 120) {
      emoji = '🔴';
      title = '$emoji 120% — Budget Exceeded!';
      body =
          'You\'ve exceeded your ${fmt.format(budget)} budget by ${fmt.format(spent - budget)}. Total: ${fmt.format(spent)}.';
    } else if (threshold <= 150) {
      emoji = '🔴';
      title = '$emoji 150% — Overspending Alert!';
      body =
          'Spending is 1.5× your budget. ${fmt.format(spent)} of ${fmt.format(budget)}.';
    } else if (threshold <= 200) {
      emoji = '🚫';
      title = '$emoji 200% — Double Budget!';
      body =
          'You\'ve spent DOUBLE your ${fmt.format(budget)} budget! Total: ${fmt.format(spent)}.';
    } else {
      // 250%, 300%, etc.
      emoji = '🚫';
      title = '$emoji ${threshold}% — Critical Overspend!';
      body =
          'Spending is ${(threshold / 100).toStringAsFixed(1)}× your budget. ${fmt.format(spent)} of ${fmt.format(budget)}.';
    }

    // For a category budget, re-title with the category name and keep the
    // numeric detail in the body. Overall-budget wording is unchanged.
    if (category != null) {
      final status = threshold < 100
          ? '$threshold% used'
          : threshold == 100
              ? 'budget limit reached'
              : '$threshold% of budget';
      title = '$emoji $category • $status';
    }

    await _notifications.show(
      // Overall budget: one slot per threshold. Category budget: one slot per
      // budget (passed in), so escalating alerts update in place.
      notificationId ?? (1000 + threshold),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_channel',
          'Budget Alerts',
          channelDescription: 'Notifications for budget thresholds',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
        ),
      ),
      payload: category != null ? 'budget_cat_$category' : 'budget_$threshold',
    );
  }

  /// Summary notification for background scans that find several
  /// transactions at once (per-transaction notifications would spam).
  Future<void> showScanSummaryNotification({
    required int count,
    required double totalAmount,
  }) async {
    if (!_isInitialized) await initialize();

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    await _notifications.show(
      2000, // Fixed ID so repeated scans update rather than stack
      '🧾 $count new transactions found',
      'Totalling ${fmt.format(totalAmount)} — tap to review and categorize',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'transaction_channel',
          'Transaction Alerts',
          channelDescription: 'Notifications for detected bank transactions',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      payload: 'scan_summary',
    );
  }

  /// Weekly nudge to tag the month's unclassified transactions. Tapping it
  /// opens the transactions list pre-filtered to Unclassified.
  Future<void> showUnclassifiedReminder({
    required int count,
    required String monthLabel,
  }) async {
    if (!_isInitialized) await initialize();
    if (count <= 0) return;

    await _notifications.show(
      3000, // Fixed ID so the weekly reminder updates rather than stacks
      '🏷️ $count transaction${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} a tag',
      'You have $count unclassified transaction${count == 1 ? '' : 's'} in '
          '$monthLabel. Tap to organize them.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'transaction_channel',
          'Transaction Alerts',
          channelDescription: 'Notifications for detected bank transactions',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      payload: openUnclassifiedPayload,
    );
  }

  /// Evening nudge to log a recurring investment whose instalment is due but
  /// wasn't auto-detected. Tapping opens the Net Worth tab to confirm it.
  Future<void> showSipReminder({
    required int count,
    String? name,
    double? amount,
  }) async {
    if (!_isInitialized) await initialize();
    if (count <= 0) return;

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final String title;
    final String body;
    if (count == 1 && name != null) {
      title = '📈 Did you invest today?';
      final amt = amount != null ? '${fmt.format(amount)} ' : '';
      body = 'We couldn\'t auto-detect your ${amt}investment in "$name". '
          'Tap to confirm and add it to your net worth.';
    } else {
      title = '📈 $count investments due';
      body = 'You have $count recurring investments to confirm for today. '
          'Tap to review and update your net worth.';
    }

    await _notifications.show(
      5000, // Fixed ID so the evening reminder updates rather than stacks
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sip_channel',
          'SIP & RD Reminders',
          channelDescription: 'Reminders to log your recurring investments',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      payload: openSipReviewPayload,
    );
  }

  Future<void> cancelAll() async => await _notifications.cancelAll();
}
