import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Holds the user's selected in-app language and exposes the matching
/// [AppStrings] table + [Locale]. Persisted to shared preferences; defaults to
/// English. Mirrors the shape of [ThemeProvider] so wiring stays familiar.
class LocaleProvider extends ChangeNotifier {
  static const String _key = 'app_language';

  AppLanguage _language = AppLanguage.english;
  bool _isInitialized = false;

  AppLanguage get language => _language;
  bool get isInitialized => _isInitialized;

  /// The string table for the active language.
  AppStrings get strings => AppStrings(_language);

  /// The locale to hand to `MaterialApp` (drives built-in widget localization).
  Locale get locale => Locale(_language.code);

  Future<void> initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _language = switch (saved) {
      'hi' => AppLanguage.hindi,
      'mr' => AppLanguage.marathi,
      'bn' => AppLanguage.bengali,
      'te' => AppLanguage.telugu,
      'ta' => AppLanguage.tamil,
      _ => AppLanguage.english,
    };
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.code);
  }
}
