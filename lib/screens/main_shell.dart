import 'package:flutter/material.dart';

import 'budget_screen.dart';
import 'home_screen.dart';
import 'net_worth_screen.dart';
import 'settings_screen.dart';

/// The app's root shell: a bottom navigation bar over four top-level sections
/// — Home (overview), Budgets (monthly + category), Net Worth (investments &
/// holdings) and Settings. Each tab keeps its own state once visited.
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
  ];

  Widget _build(int i) {
    switch (i) {
      case 1:
        return const BudgetScreen();
      case 2:
        return const NetWorthScreen();
      case 3:
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline_rounded),
            activeIcon: Icon(Icons.pie_chart_rounded),
            label: 'Budgets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Net Worth',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
