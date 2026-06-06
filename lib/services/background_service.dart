import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'sms_service.dart';

/// Background service for scheduled SMS scanning
class BackgroundService {
  static const String scanTaskName = 'sms_scan_task';
  static const String scanTaskUniqueName = 'budget_tracker_sms_scan';

  // Preferences keys
  static const String _autoScanEnabledKey = 'auto_scan_enabled';
  static const String _scanTime1Key = 'scan_time_1';
  static const String _scanTime2Key = 'scan_time_2';
  static const String _lastScanTimeKey = 'last_scan_time';

  /// Initialize the background service
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  /// Check if auto-scan is enabled
  static Future<bool> isAutoScanEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoScanEnabledKey) ?? false;
  }

  /// Get scan times (returns list of TimeOfDay-like maps)
  static Future<Map<String, dynamic>> getScanSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_autoScanEnabledKey) ?? false,
      'time1': prefs.getString(_scanTime1Key) ?? '14:55', // 5 mins before 3 PM
      'time2': prefs.getString(_scanTime2Key), // Optional second scan
    };
  }

  /// Save scan settings
  static Future<void> saveScanSettings({
    required bool enabled,
    required String time1,
    String? time2,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoScanEnabledKey, enabled);
    await prefs.setString(_scanTime1Key, time1);
    if (time2 != null) {
      await prefs.setString(_scanTime2Key, time2);
    } else {
      await prefs.remove(_scanTime2Key);
    }

    // Register or cancel background tasks based on settings
    if (enabled) {
      await _registerBackgroundTask();
    } else {
      await _cancelBackgroundTask();
    }
  }

  /// Register periodic background task
  static Future<void> _registerBackgroundTask() async {
    // Cancel existing tasks first
    await _cancelBackgroundTask();

    // Register periodic task - runs approximately every 12 hours
    // Workmanager will handle the exact timing based on device state
    await Workmanager().registerPeriodicTask(
      scanTaskUniqueName,
      scanTaskName,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      initialDelay: _calculateInitialDelay(),
    );
  }

  /// Calculate initial delay to start around first scheduled time
  static Duration _calculateInitialDelay() {
    final now = DateTime.now();
    // Default first scan at 2:55 PM (5 mins before 3 PM)
    var targetTime = DateTime(now.year, now.month, now.day, 14, 55);

    if (now.isAfter(targetTime)) {
      // If past first scan time, target next day
      targetTime = targetTime.add(const Duration(days: 1));
    }

    return targetTime.difference(now);
  }

  /// Cancel background tasks
  static Future<void> _cancelBackgroundTask() async {
    await Workmanager().cancelByUniqueName(scanTaskUniqueName);
  }

  /// Record last scan time
  static Future<void> _recordScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastScanTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get last scan time
  static Future<DateTime?> getLastScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastScanTimeKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Perform the background SMS scan
  static Future<void> performBackgroundScan() async {
    try {
      final smsService = SmsService();

      // Check if we have permission
      if (!await smsService.hasPermission()) {
        return;
      }

      // Scan SMS and auto-classify using rules
      await smsService.scanExistingSms(maxCount: 50);

      // Record scan time
      await _recordScanTime();
    } catch (e) {
      // Silently fail in background
    }
  }

  /// Perform a foreground SMS scan (called when app opens).
  /// Returns the list of newly found transactions.
  static Future<List<TransactionModel>> performForegroundScan({
    int maxCount = 100,
  }) async {
    try {
      final smsService = SmsService();

      // Check if we have permission
      if (!await smsService.hasPermission()) {
        return [];
      }

      // Scan SMS and auto-classify
      final transactions = await smsService.scanExistingSms(
        maxCount: maxCount,
      );

      // Record scan time
      await _recordScanTime();

      return transactions;
    } catch (e) {
      // Silently fail
      return [];
    }
  }
}

/// Top-level callback for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == BackgroundService.scanTaskName) {
      await BackgroundService.performBackgroundScan();
    }
    return Future.value(true);
  });
}
