import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/transaction_model.dart';
import 'package:intl/intl.dart';

/// Service for showing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

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

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {}

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
  Future<void> showBudgetNotification({
    required int threshold,
    required double spent,
    required double budget,
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

    await _notifications.show(
      1000 + threshold, // Unique ID per threshold level
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
      payload: 'budget_$threshold',
    );
  }

  Future<void> cancelAll() async => await _notifications.cancelAll();
}
