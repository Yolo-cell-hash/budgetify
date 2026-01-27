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
        importance: Importance.high,
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

  /// Show budget threshold notification
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
    String title, body;

    switch (threshold) {
      case 50:
        title = '⚠️ 50% Budget Used';
        body =
            'Spent ${fmt.format(spent)} of ${fmt.format(budget)}. Stay on track!';
        break;
      case 90:
        title = '🔶 90% Budget Used';
        body =
            'Spent ${fmt.format(spent)} of ${fmt.format(budget)}. Only ${fmt.format(budget - spent)} left!';
        break;
      case 100:
        title = '🚨 Budget Exceeded!';
        body =
            'You\'ve exceeded ${fmt.format(budget)}. Total: ${fmt.format(spent)}';
        break;
      default:
        return;
    }

    await _notifications.show(
      1000 + threshold,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_channel',
          'Budget Alerts',
          channelDescription: 'Notifications for budget thresholds',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      payload: 'budget_$threshold',
    );
  }

  Future<void> cancelAll() async => await _notifications.cancelAll();
}
