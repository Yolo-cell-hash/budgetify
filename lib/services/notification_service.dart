import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/transaction_model.dart';
import '../screens/transactions_screen.dart';
import '../screens/net_worth_screen.dart';
import '../screens/recurring_screen.dart';
import 'sip_service.dart';
import 'recurring_service.dart';
import 'package:intl/intl.dart';

/// Action button ids on the "Investment Alert" SIP/RD prompt.
const String sipYesAction = 'sip_yes';
const String sipNoAction = 'sip_no';

/// Action button ids on the "Bill reminder" recurring-payment prompt.
const String billPaidAction = 'bill_paid';
const String billSkipAction = 'bill_skip';

/// Status-bar (small) icon for every notification. Android renders the small
/// icon as an alpha-only silhouette, so the full-colour launcher icon
/// (`@mipmap/ic_launcher`) shows up as a solid white/black square — the bug
/// testers saw. This points at a dedicated white-on-transparent vector
/// (`res/drawable/ic_stat_notify.xml`); a vector is safe because the app's
/// minSdk is 24. Bare name: the plugin resolves it via
/// getResources().getIdentifier(name, "drawable", package).
const String _notificationIcon = 'ic_stat_notify';

/// Background isolate handler for notification action buttons. Must be a
/// top-level, vm:entry-point function. Used for the silent "No"/"Skip" paths;
/// the affirmative actions open the app and are handled in the main isolate for
/// reliability. Each resolver is guarded by its own action ids, so dispatching
/// to both here is safe.
@pragma('vm:entry-point')
void notificationActionBackgroundHandler(NotificationResponse response) {
  resolveSipNotificationAction(response.actionId, response.payload);
  resolveRecurringNotificationAction(response.actionId, response.payload);
}

/// Parse a `sip:<id>:<period>` payload and resolve the instalment. Idempotent.
void resolveSipNotificationAction(String? actionId, String? payload) {
  if (actionId != sipYesAction && actionId != sipNoAction) return;
  if (payload == null || !payload.startsWith('sip:')) return;
  final parts = payload.split(':');
  if (parts.length < 3) return;
  final id = int.tryParse(parts[1]);
  if (id == null) return;
  // Fire-and-forget; resolveFromAction is idempotent and quick.
  SipService().resolveFromAction(id, parts[2], actionId == sipYesAction);
}

/// Parse a `bill:<planId>:<periodKey>` payload and resolve the cycle.
/// Idempotent. [periodKey] is `YYYY-MM-DD` (hyphens only, so it survives the
/// `:` split).
void resolveRecurringNotificationAction(String? actionId, String? payload) {
  if (actionId != billPaidAction && actionId != billSkipAction) return;
  if (payload == null || !payload.startsWith('bill:')) return;
  final parts = payload.split(':');
  if (parts.length < 3) return;
  final id = int.tryParse(parts[1]);
  if (id == null) return;
  RecurringService().resolveFromAction(id, parts[2], actionId == billPaidAction);
}

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

  /// Payload that routes to the Recurring payments screen.
  static const String openRecurringPayload = 'open_recurring';

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Initialize the notification service.
  ///
  /// Wrapped in try/catch so a notification-subsystem failure can NEVER block
  /// app startup. The plugin's `initialize` throws if the small icon can't be
  /// resolved (e.g. the drawable isn't in the build yet); since this is awaited
  /// in `main()` before `runApp`, an uncaught throw here would leave the app
  /// stuck on the native splash. The app must still open even if notifications
  /// can't start.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(_notificationIcon);
      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse:
            notificationActionBackgroundHandler,
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

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'recurring_channel',
          'Bill Reminders',
          description: 'Reminders for upcoming subscriptions, rent and bills',
          importance: Importance.high,
        ),
      );

      _isInitialized = true;
    } catch (e, st) {
      debugPrint('NotificationService.initialize failed (continuing): $e\n$st');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == sipYesAction || actionId == sipNoAction) {
      resolveSipNotificationAction(actionId, response.payload);
      // "Yes" opens the app to the Net Worth review so the user sees it land.
      if (actionId == sipYesAction) _routeForPayload(openSipReviewPayload);
      return;
    }
    if (actionId == billPaidAction || actionId == billSkipAction) {
      resolveRecurringNotificationAction(actionId, response.payload);
      // "Paid" opens the Recurring screen so the user sees it land.
      if (actionId == billPaidAction) _routeForPayload(openRecurringPayload);
      return;
    }
    _routeForPayload(response.payload);
  }

  /// If the app was cold-started by tapping a notification (or its action),
  /// resolve/route once the first frame (and navigator) is ready.
  Future<void> handleLaunchPayload() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (!(details?.didNotificationLaunchApp ?? false)) return;
    final response = details!.notificationResponse;
    final actionId = response?.actionId;
    if (actionId == sipYesAction || actionId == sipNoAction) {
      resolveSipNotificationAction(actionId, response?.payload);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routeForPayload(openSipReviewPayload),
      );
      return;
    }
    if (actionId == billPaidAction || actionId == billSkipAction) {
      resolveRecurringNotificationAction(actionId, response?.payload);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routeForPayload(openRecurringPayload),
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _routeForPayload(response?.payload),
    );
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
    } else if (payload == openRecurringPayload) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const RecurringScreen()),
      );
    }
  }

  Future<void> showTransactionNotification(TransactionModel transaction) async {
    if (!_isInitialized) await initialize();

    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final amountStr = formatter.format(transaction.amount);
    final isCredit = transaction.type == TransactionType.credit;

    // When the transaction is already tagged with a real spending category
    // (e.g. a saved rule auto-classified it), name it — "₹50 spent towards
    // Food" — otherwise fall back to the plain "₹50 spent". Non-expense tags
    // (Self Transfer / Investments / Settlement) and untagged debits stay plain.
    final cat = transaction.category;
    final hasSpendTag = !isCredit &&
        transaction.isClassified &&
        cat != null &&
        cat.isNotEmpty &&
        ExpenseCategories.isExpenseCategory(cat);
    final body = isCredit
        ? '$amountStr received'
        : (hasSpendTag ? '$amountStr spent towards $cat' : '$amountStr spent');

    await _notifications.show(
      transaction.detectedAt.millisecondsSinceEpoch ~/ 1000,
      isCredit ? '💰 Money Credited' : '💸 Money Debited',
      body,
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

  /// Celebratory notification fired when a savings goal reaches its target.
  Future<void> showGoalAchieved({
    required String name,
    required double amount,
  }) async {
    if (!_isInitialized) await initialize();
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    await _notifications.show(
      4100 + (name.hashCode.abs() % 1000),
      '🎉 Goal reached: $name',
      'You saved ${fmt.format(amount)} — congratulations!',
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
      payload: 'goal_achieved',
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

  /// "Investment Alert" for a recurring investment due today, with Yes / No
  /// action buttons. Tapping **Yes** opens the app and logs the instalment
  /// (handled in the main isolate for reliability); **No** marks it skipped
  /// silently. The body opens the Net Worth review. A stable per-plan id keeps
  /// the noon prompt and its 8 PM follow-up in the same slot.
  Future<void> showSipPrompt({
    required int sipId,
    required String name,
    double? amount,
    required String periodKey,
    required bool evening,
  }) async {
    if (!_isInitialized) await initialize();

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final amt = amount != null ? '${fmt.format(amount)} ' : '';
    final body = 'Did you make your ${amt}investment in "$name" today? '
        'Tap Yes to add it to your net worth.';

    await _notifications.show(
      6000 + sipId, // one slot per plan; noon prompt is replaced at 8 PM
      '🔔 Investment Alert',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sip_channel',
          'SIP & RD Reminders',
          channelDescription: 'Reminders to log your recurring investments',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              sipYesAction,
              'Yes, I did',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              sipNoAction,
              'No',
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: 'sip:$sipId:$periodKey',
    );
  }

  /// "Bill reminder" for a recurring expense due (or overdue), with Paid / Skip
  /// action buttons. **Paid** opens the app and logs it; **Skip** marks the
  /// cycle skipped silently. A stable per-plan id keeps the noon prompt and its
  /// 8 PM follow-up in the same slot. [periodKey] is `YYYY-MM-DD` of the due.
  Future<void> showRecurringPrompt({
    required int planId,
    required String name,
    double? amount,
    required String periodKey,
    required bool overdue,
  }) async {
    if (!_isInitialized) await initialize();

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final amt = amount != null ? '${fmt.format(amount)} ' : '';
    final title = overdue ? '⏰ Bill overdue' : '🔔 Bill reminder';
    final body = overdue
        ? 'Your ${amt}payment for "$name" looks overdue. Did you pay it?'
        : 'Your ${amt}payment for "$name" is due. Did you pay it?';

    await _notifications.show(
      7000 + planId, // one slot per plan; noon prompt is replaced at 8 PM
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_channel',
          'Bill Reminders',
          channelDescription:
              'Reminders for upcoming subscriptions, rent and bills',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              billPaidAction,
              'Yes, paid',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              billSkipAction,
              'Skip',
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: 'bill:$planId:$periodKey',
    );
  }

  Future<void> cancelAll() async => await _notifications.cancelAll();
}
