import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/app_events.dart';
import '../services/tutorial_service.dart';
import '../widgets/spotlight.dart';
import 'budget_screen.dart';
import 'home_screen.dart';
import 'net_worth_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';

/// The app's root shell: a bottom navigation bar over five top-level sections
/// — Home (overview), Budgets (monthly + category), Recurring (subscriptions,
/// rent, EMIs & bills), Net Worth (investments & holdings) and Settings.
/// Recurring sits in the centre slot so it's as reachable as the rest. Each
/// tab keeps its own state once visited.
///
/// Tabs are built lazily (only when first opened) and then kept alive via the
/// [IndexedStack], so startup stays light on low-end devices but switching
/// tabs is instant afterwards.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Fades the tab body out and back in during programmatic switches (e.g.
  // Settings sending the user Home after enabling Gamified Budgets), so the
  // jump reads as a gentle hand-off instead of an instant swap. User taps on
  // the bar stay instant, as expected.
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    // Lets other screens send the user to a tab (e.g. Settings switching to
    // Home right after Gamified Budgets is enabled, so the new entry point
    // can be spotlighted there).
    mainShellTabRequest.addListener(_onTabRequest);
    // The tour's "tap this tab" tips are anchored on the bottom bar, which
    // belongs to this shell — so the shell shows them whichever tab is open.
    TutorialService.instance.addListener(_onTutorialTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTabTip());
  }

  @override
  void dispose() {
    TutorialService.instance.removeListener(_onTutorialTick);
    mainShellTabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTutorialTick() {
    if (mounted) _maybeShowTabTip();
  }

  /// The tab a tour step points at (null for non-tab steps).
  static int? _tabForStep(TutorialStep step) => switch (step) {
        TutorialStep.budgetsTab => 1,
        TutorialStep.recurringTab => 2,
        TutorialStep.investTab => 3,
        TutorialStep.settingsTab => 4,
        _ => null,
      };

  /// Shows the "tap the highlighted tab" tour tips (the tap passes through to
  /// the real bar). If the user is already sitting on the target tab, the
  /// step auto-completes — tapping the active tab is a no-op, so waiting for
  /// it would deadlock the tour.
  void _maybeShowTabTip() {
    if (!mounted) return;
    final svc = TutorialService.instance;
    final step = svc.step;
    final target = _tabForStep(step);
    if (target == null) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    if (_index == target) {
      svc.advanceFrom(step);
      return;
    }
    final l10n = context.l10nRead;
    final (anchor, title) = switch (step) {
      TutorialStep.budgetsTab => (
          TutorialAnchors.budgetsTab,
          l10n.tutBudgetsTitle,
        ),
      TutorialStep.recurringTab => (
          TutorialAnchors.recurringTab,
          l10n.tutRecurringTabTitle,
        ),
      TutorialStep.investTab => (
          TutorialAnchors.investTab,
          l10n.tutInvestTitle,
        ),
      _ => (
          TutorialAnchors.settingsTab,
          l10n.tutSettingsTabTitle,
        ),
    };
    TutorialTips.show(
      context,
      step: step,
      anchor: anchor,
      title: title,
      message: l10n.tutTapTabBody,
      shape: SpotlightShape.circle,
    );
  }

  void _onTabRequest() {
    final i = mainShellTabRequest.value;
    if (i == null || !mounted) return;
    mainShellTabRequest.value = null;
    if (i >= 0 && i < _pages.length) _softSelect(i);
  }

  // Home is built immediately; the rest are created on first visit.
  late final List<Widget?> _pages = <Widget?>[
    const HomeScreen(),
    null,
    null,
    null,
    null,
  ];

  Widget _build(int i) {
    switch (i) {
      case 1:
        return const BudgetScreen();
      case 2:
        return const RecurringScreen();
      case 3:
        return const NetWorthScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }

  void _select(int i) {
    if (i == _index) return;
    // Any live tutorial tip is anchored to the outgoing tab — drop it; the
    // owning screen re-shows it when it becomes visible again.
    TutorialTips.dismiss();
    setState(() {
      _index = i;
      _pages[i] ??= _build(i);
    });
    mainShellTabIndex.value = i;
    _completeTabStep(i);
    TutorialService.instance.poke();
  }

  /// Programmatic tab change with a soft cross-fade.
  Future<void> _softSelect(int i) async {
    if (i == _index || _fading) return;
    TutorialTips.dismiss();
    setState(() => _fading = true);
    await Future.delayed(const Duration(milliseconds: 170));
    if (!mounted) return;
    setState(() {
      _index = i;
      _pages[i] ??= _build(i);
      _fading = false;
    });
    mainShellTabIndex.value = i;
    _completeTabStep(i);
    TutorialService.instance.poke();
  }

  /// Landing on a tab completes the tour step that asked for it.
  void _completeTabStep(int i) {
    final svc = TutorialService.instance;
    switch (i) {
      case 1:
        svc.advanceFrom(TutorialStep.budgetsTab);
      case 2:
        svc.advanceFrom(TutorialStep.recurringTab);
      case 3:
        svc.advanceFrom(TutorialStep.investTab);
      case 4:
        svc.advanceFrom(TutorialStep.settingsTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOpacity(
        opacity: _fading ? 0.0 : 1.0,
        duration: Duration(milliseconds: _fading ? 160 : 320),
        curve: _fading ? Curves.easeOut : Curves.easeIn,
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _pages[i] ?? const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _select,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: context.l10n.navHome,
          ),
          BottomNavigationBarItem(
            // KeyedSubtree anchors let the guided tour spotlight these tabs.
            icon: KeyedSubtree(
              key: TutorialAnchors.budgetsTab,
              child: const Icon(Icons.pie_chart_outline_rounded),
            ),
            activeIcon: const Icon(Icons.pie_chart_rounded),
            label: context.l10n.navBudgets,
          ),
          BottomNavigationBarItem(
            icon: KeyedSubtree(
              key: TutorialAnchors.recurringTab,
              child: const Icon(Icons.event_repeat_outlined),
            ),
            activeIcon: const Icon(Icons.event_repeat_rounded),
            label: context.l10n.navRecurring,
          ),
          BottomNavigationBarItem(
            icon: KeyedSubtree(
              key: TutorialAnchors.investTab,
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            activeIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: context.l10n.navNetWorth,
          ),
          BottomNavigationBarItem(
            icon: KeyedSubtree(
              key: TutorialAnchors.settingsTab,
              child: const Icon(Icons.settings_outlined),
            ),
            activeIcon: const Icon(Icons.settings_rounded),
            label: context.l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
