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

/// The main shell's currently visible tab (0 = Home). Screens inside the
/// shell's IndexedStack stay mounted while hidden, so tab-scoped UI (like the
/// guided tour's tips) checks this before showing anything.
final ValueNotifier<int> mainShellTabIndex = ValueNotifier<int>(0);

/// A one-shot reaction the equipped ROYALTY avatar can play on the Home header
/// — purely cosmetic (rendered by royal_reactions.dart). Strictly QOL: nothing
/// in this pathway reads or writes core data, and if no royal is equipped (or
/// Gamified Budgets is off) there simply is no listener, so it's a silent no-op.
enum RoyalReaction {
  /// A weapon strike — e.g. after deleting a transaction (the royal "vanquishes"
  /// it).
  strike,

  /// An angry weapon slam — e.g. when a budget is exceeded.
  scold,

  /// A happy flourish — e.g. when financial health turns healthy.
  cheer,
}

/// A reaction plus a monotonic nonce, so the SAME reaction firing twice in a
/// row still notifies listeners (a bare enum value wouldn't change).
class RoyalReactionEvent {
  final RoyalReaction reaction;
  final int nonce;
  const RoyalReactionEvent(this.reaction, this.nonce);
}

/// Latest requested royal reaction, consumed by the Home avatar. Null until the
/// first request.
final ValueNotifier<RoyalReactionEvent?> royalReactionRequest =
    ValueNotifier<RoyalReactionEvent?>(null);

int _royalReactionNonce = 0;

/// Ask the Home royal avatar to play [reaction]. Fire-and-forget and always
/// safe: it only updates a notifier, never blocks, and does nothing visible
/// unless a royal avatar is on the Home header.
void requestRoyalReaction(RoyalReaction reaction) {
  royalReactionRequest.value =
      RoyalReactionEvent(reaction, ++_royalReactionNonce);
}
