import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lock backed by the platform's biometric prompt (fingerprint / face)
/// with device-credential (PIN/pattern) fallback.
class AppLockService {
  static const String _enabledKey = 'app_lock_enabled';

  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Whether the device can authenticate at all (biometrics enrolled or a
  /// PIN/pattern/password set).
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Show the system authentication prompt. Face and fingerprint are both
  /// offered automatically; the device PIN works as fallback.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Budgetify to view your finances',
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
