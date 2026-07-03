import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../widgets/spotlight.dart';

/// The guided, in-context tutorial. Instead of a slideshow, each step is a
/// coach mark anchored to the real control, and — game-style — the action
/// steps advance only when the user actually performs the action:
///
/// 1. A scanned transaction appears on Home → "tap it" (tap passes through)
/// 2. The transactions list → "open this transaction"
/// 3. The detail screen → "pick a tag", then "save it"
/// 4. The apply-options sheet explains Apply to All / Existing / Only This One
/// 5. Classifying pops the user straight back to Home, where info tips cover
///    the Financial Health score and Savings Goals; the tour then walks INTO
///    every section — the user taps each highlighted tab and gets a guided
///    chain in place:
///    · Budgets: the Set-Budget button → the calendar heatmap → per-category
///      caps → the Trends tab (the tour drives the tab bar itself)
///    · Recurring: intro → tap Add to open the editor, which carries a
///      one-time explainer (cadence, due date, reminders) → close unsaved
///    · Net Worth: intro → tap Add → the holding editor explains asset types
///      (FD = one-time; RD/SIP recur and remind on the entered date) and
///      liabilities → close unsaved
///    · Settings: the Intelligence power-ups → backup/import/export → the
///      personalisation section, then Finish cross-fades back Home.
///
/// Progress persists across launches; every tip offers "Skip tour"; the tour
/// can be replayed from Settings → About. All copy resolves through the
/// active [AppStrings] table, so the tour runs in the language chosen during
/// onboarding.
enum TutorialStep {
  viewTransactions,
  openTransaction,
  chooseTag,
  saveTag,
  applyOptions,
  health,
  goals,
  budgetsTab,
  budgetsIntro,
  budgetsSetBudget,
  budgetsHeatmap,
  budgetsCategories,
  budgetsCategorySheet,
  budgetsTrends,
  recurringTab,
  recurringIntro,
  recurringAdd,
  recurringEditor,
  investTab,
  investIntro,
  investAdd,
  investEditor,
  settingsTab,
  settingsAi,
  settingsHealth,
  settingsGamified,
  settingsData,
  settingsMore,
  done,
}

class TutorialService extends ChangeNotifier {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  // v4: the step list grew again (dialog walkthroughs, per-toggle Settings
  // stops), so stored v3 indexes no longer line up — a fresh key simply
  // restarts the tour once.
  static const String _stepKey = 'tutorial_step_v4';

  TutorialStep _step = TutorialStep.done;
  bool _loaded = false;

  /// Reads as [TutorialStep.done] until [load] completes, so triggers that
  /// fire before then are inert rather than wrong.
  TutorialStep get step => _loaded ? _step : TutorialStep.done;
  bool get isDone => step == TutorialStep.done;
  bool isAt(TutorialStep s) => step == s;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_stepKey) ?? 0;
    _step = TutorialStep.values[saved.clamp(0, TutorialStep.values.length - 1)];
    _loaded = true;
    notifyListeners();
  }

  /// Jump forward to [next]. Backward moves are ignored, so stray triggers
  /// can never rewind the tour.
  void advanceTo(TutorialStep next) {
    if (!_loaded || next.index <= _step.index) return;
    _step = next;
    notifyListeners();
    _persist();
  }

  /// Advance one step, but only when the tour is currently at [current] —
  /// every trigger names the step it completes, so out-of-order events are
  /// harmless no-ops.
  void advanceFrom(TutorialStep current) {
    if (isAt(current)) {
      advanceTo(TutorialStep.values[current.index + 1]);
    }
  }

  void skipAll() => advanceTo(TutorialStep.done);

  /// Start the tour over (Settings → About → App tour).
  Future<void> restart() async {
    _loaded = true;
    _step = TutorialStep.viewTransactions;
    notifyListeners();
    await _persist();
  }

  /// Re-broadcast the current step so visible screens re-evaluate their tips
  /// (e.g. after a bottom-nav switch reveals Home again).
  void poke() => notifyListeners();

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepKey, _step.index);
  }

  @visibleForTesting
  void debugReset() {
    _loaded = false;
    _step = TutorialStep.done;
  }
}

/// Anchors for tour tips that point at the bottom navigation bar, which lives
/// in the main shell while the tips are driven from the Home tab.
class TutorialAnchors {
  TutorialAnchors._();
  static final GlobalKey budgetsTab = GlobalKey();
  static final GlobalKey recurringTab = GlobalKey();
  static final GlobalKey investTab = GlobalKey();
  static final GlobalKey settingsTab = GlobalKey();
}

/// Presents at most one tutorial tip at a time and tears it down whenever the
/// step moves on (the awaited action happened) or the owning screen goes away.
class TutorialTips {
  TutorialTips._();

  static SpotlightHandle? _handle;
  static TutorialStep? _shownFor;
  static bool _listening = false;

  // Monotonic ticket: every new show()/dismiss() invalidates in-flight show
  // attempts (they await scrolling/retries), so overlapping calls can't
  // clobber each other's overlay — the latest request wins.
  static int _seq = 0;

  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    TutorialService.instance.addListener(() {
      final shown = _shownFor;
      // Close a stale tip WITHOUT bumping the ticket: when a step advances,
      // the new step's show() is usually already in flight (listeners fire in
      // registration order) and must survive this cleanup — bumping here is
      // what used to strand the tour between steps.
      if (shown != null && !TutorialService.instance.isAt(shown)) {
        _closeHandle();
      }
    });
  }

  /// Show the tip for [step] anchored to [anchor]: scrolls it into view and
  /// retries briefly while it builds. With [advanceIfMissing], an anchor that
  /// never appears (that card isn't on this dashboard) skips its step instead
  /// of stalling the tour.
  static Future<void> show(
    BuildContext context, {
    required TutorialStep step,
    required GlobalKey anchor,
    required String title,
    required String message,
    SpotlightShape shape = SpotlightShape.rrect,
    bool passthrough = true,
    String? buttonLabel,
    VoidCallback? onButton,
    bool advanceIfMissing = false,
    VoidCallback? onMissing,
  }) async {
    _ensureListening();
    final svc = TutorialService.instance;
    if (_shownFor == step && (_handle?.isShowing ?? false)) return;
    final ticket = ++_seq;

    for (var attempt = 0; attempt < 8; attempt++) {
      if (ticket != _seq || !context.mounted || !svc.isAt(step)) return;
      final anchorContext = anchor.currentContext;
      if (anchorContext != null) {
        await Scrollable.ensureVisible(
          anchorContext,
          duration: const Duration(milliseconds: 280),
          alignment: 0.3,
        );
        if (ticket != _seq || !context.mounted || !svc.isAt(step)) return;
        if (_shownFor == step && (_handle?.isShowing ?? false)) return;
        _closeHandle();
        final handle = showSpotlightTip(
          context,
          targetKey: anchor,
          title: title,
          message: message,
          shape: shape,
          passthrough: passthrough,
          buttonLabel: buttonLabel,
          onButton: onButton,
          skipLabel: context.l10nRead.tutSkip,
          onSkip: svc.skipAll,
        );
        if (handle != null) {
          _handle = handle;
          _shownFor = step;
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    // Anchor never appeared. [onMissing] lets multi-step chains skip past
    // their dependent steps (e.g. a dialog walkthrough that can't open).
    if (onMissing != null) {
      onMissing();
    } else if (advanceIfMissing) {
      svc.advanceFrom(step);
    }
  }

  /// External cancellation (tab switch, screen dispose): closes the tip AND
  /// invalidates in-flight show attempts.
  static void dismiss() {
    _seq++;
    _closeHandle();
  }

  /// Close whatever tip is up without cancelling in-flight show attempts.
  static void _closeHandle() {
    _handle?.close();
    _handle = null;
    _shownFor = null;
  }

  /// Dismiss only if the visible tip belongs to [step] — screens call this on
  /// dispose for the steps they own.
  static void dismissIfFor(TutorialStep step) {
    if (_shownFor == step) dismiss();
  }
}
