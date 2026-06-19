import 'package:flutter/foundation.dart';

/// Bumped whenever the underlying data changes outside a screen's own flow —
/// most importantly after a **backup restore**, which rewrites the database
/// while the Home tab is kept alive in the background. Always-on screens listen
/// to this and reload themselves, so counts and totals refresh without the user
/// having to trigger a scan.
final ValueNotifier<int> appDataRevision = ValueNotifier<int>(0);

/// Signal that on-device data changed and any live screen should refresh.
void notifyAppDataChanged() => appDataRevision.value++;
