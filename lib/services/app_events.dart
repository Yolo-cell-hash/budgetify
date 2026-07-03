import 'package:flutter/foundation.dart';

/// Bumped whenever the underlying data changes outside a screen's own flow —
/// most importantly after a **backup restore**, which rewrites the database
/// while the Home tab is kept alive in the background. Always-on screens listen
/// to this and reload themselves, so counts and totals refresh without the user
/// having to trigger a scan.
final ValueNotifier<int> appDataRevision = ValueNotifier<int>(0);

/// Signal that on-device data changed and any live screen should refresh.
void notifyAppDataChanged() => appDataRevision.value++;

/// One-shot request for the main shell to switch tabs (e.g. Settings sending
/// the user Home right after Gamified Budgets is enabled, so the new entry
/// point can be pointed out). The shell consumes the value and resets it to
/// null.
final ValueNotifier<int?> mainShellTabRequest = ValueNotifier<int?>(null);

/// One-shot spotlight request for the Home screen (currently 'rewards', sent
/// when Gamified Budgets is switched on). Home consumes and clears it.
final ValueNotifier<String?> homeSpotlightRequest =
    ValueNotifier<String?>(null);
