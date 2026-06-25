import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
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
    setState(() {
      _index = i;
      _pages[i] ??= _build(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _pages.length; i++)
            _pages[i] ?? const SizedBox.shrink(),
        ],
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
            icon: const Icon(Icons.pie_chart_outline_rounded),
            activeIcon: const Icon(Icons.pie_chart_rounded),
            label: context.l10n.navBudgets,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.event_repeat_outlined),
            activeIcon: const Icon(Icons.event_repeat_rounded),
            label: context.l10n.navRecurring,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            activeIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: context.l10n.navNetWorth,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings_rounded),
            label: context.l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
