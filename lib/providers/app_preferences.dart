import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app preferences (onboarding, privacy, etc.)
class AppPreferences extends ChangeNotifier {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _privacyModeKey = 'privacy_mode';
  static const String _aiPredictionModeKey = 'ai_prediction_mode';
  static const String _financialHealthDetailedKey =
      'financial_health_detailed';
  static const String _gamifiedModeKey = 'gamified_mode';
  static const String _dismissedBudgetSuggestionsKey =
      'dismissed_budget_suggestions';

  bool _isOnboardingComplete = false;
  bool _isInitialized = false;

  // Categories for which the user has dismissed the "set a budget" suggestion,
  // so we don't keep nudging them about the same spend category.
  Set<String> _dismissedBudgetSuggestions = {};

  // Privacy mode hides/blurs monetary amounts. The on/off preference is
  // persisted; whether amounts are momentarily revealed is session-only
  // (it always resets to hidden on a fresh launch).
  bool _privacyMode = false;
  bool _amountsRevealed = false;

  // AI Prediction Mode (opt-in, default off). Gates the on-device spending
  // insights & forecast UI — when off, the app behaves exactly as before and
  // no insight numbers are computed or shown.
  bool _aiPredictionMode = false;

  // When on, the home dashboard shows the full Financial Health breakdown card.
  // When off (default), only a compact score indicator is shown on the balance
  // card — keeps the dashboard uncluttered while the number stays visible.
  bool _financialHealthDetailed = false;

  // Gamified Budgets (default ON). Unlocks achievements, titles, streak
  // rewards and a shareable profile via a separate Rewards hub. Users who'd
  // rather keep things plain can switch it off in Settings — turning it off
  // removes the Home avatar and every gamified addition.
  bool _gamifiedMode = true;

  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isInitialized => _isInitialized;
  bool get privacyMode => _privacyMode;
  bool get aiPredictionMode => _aiPredictionMode;
  bool get financialHealthDetailed => _financialHealthDetailed;
  bool get gamifiedMode => _gamifiedMode;

  /// Whether amounts should currently render hidden: privacy mode is on and
  /// the user hasn't tapped to reveal this session.
  bool get amountsHidden => _privacyMode && !_amountsRevealed;

  /// Initialize from shared preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isOnboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;
    _privacyMode = prefs.getBool(_privacyModeKey) ?? false;
    _aiPredictionMode = prefs.getBool(_aiPredictionModeKey) ?? false;
    _financialHealthDetailed =
        prefs.getBool(_financialHealthDetailedKey) ?? false;
    _gamifiedMode = prefs.getBool(_gamifiedModeKey) ?? true;
    _dismissedBudgetSuggestions =
        (prefs.getStringList(_dismissedBudgetSuggestionsKey) ?? const [])
            .toSet();

    _isInitialized = true;
    notifyListeners();
  }

  /// Whether the budget suggestion for [category] has been dismissed.
  bool isBudgetSuggestionDismissed(String category) =>
      _dismissedBudgetSuggestions.contains(category);

  /// Permanently dismiss the "set a budget" suggestion for [category].
  Future<void> dismissBudgetSuggestion(String category) async {
    if (!_dismissedBudgetSuggestions.add(category)) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dismissedBudgetSuggestionsKey,
      _dismissedBudgetSuggestions.toList(),
    );
  }

  /// Turn privacy mode on/off (persisted). Turning it on re-hides amounts.
  Future<void> setPrivacyMode(bool enabled) async {
    _privacyMode = enabled;
    _amountsRevealed = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyModeKey, enabled);
  }

  /// Momentarily reveal (or re-hide) amounts while privacy mode is on.
  void toggleReveal() {
    if (!_privacyMode) return;
    _amountsRevealed = !_amountsRevealed;
    notifyListeners();
  }

  /// Turn AI Prediction Mode on/off (persisted).
  Future<void> setAiPredictionMode(bool enabled) async {
    _aiPredictionMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiPredictionModeKey, enabled);
  }

  /// Show the full Financial Health breakdown card vs. the compact indicator
  /// (persisted).
  Future<void> setFinancialHealthDetailed(bool enabled) async {
    _financialHealthDetailed = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_financialHealthDetailedKey, enabled);
  }

  /// Turn Gamified Budgets on/off (persisted).
  Future<void> setGamifiedMode(bool enabled) async {
    _gamifiedMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gamifiedModeKey, enabled);
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    _isOnboardingComplete = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    _isOnboardingComplete = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, false);
  }
}
