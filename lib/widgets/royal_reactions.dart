import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_preferences.dart';
import '../services/app_events.dart';
import '../services/financial_health_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_service.dart';
import 'royal_avatars.dart';
import 'royal_character.dart';

/// The "living court": pocket-size, full-body ROYALTY avatars that inhabit the
/// app. They emerge from the Home profile icon for the big moments — a welcome
/// parade at launch (with their royal ride), a weapon attack on the screen
/// when the user blows a budget, a cheer for good behaviour — and, between
/// moments, drop rare ambient CAMEOS anywhere in the app: strolling along the
/// bottom of whatever page is open, galloping across on their mount, peeking
/// in from a screen edge, or popping up at a random spot for a tiny
/// celebration.
///
/// The budget attack is per-royal — each weapon fights its own way and leaves
/// its own damage ([_ShatterPainter]): the Sovereign slashes an X with his
/// sword of state, the Prince lunges his arming sword clean through in one
/// long gash, the Dark Prince's club blows a full spiderweb crater, the
/// Princess feathers the screen with arrows, the Empress detonates hurled
/// orbs, the Medic slams a shock pulse.
/// On the Budgets tab the strike lands on the MONTHLY BUDGET gauge
/// ([royalBudgetChartAnchorKey]) — the royal runs in from its anchor, jumps
/// up onto the ring, wrecks it and hops back down; elsewhere it plays out
/// near the profile anchor. Impacts also rumble the device (see
/// [_fireImpactHaptic]).
///
/// Strictly-additive QOL: everything renders as a transient overlay above the
/// app, ignores pointers, and never reads/writes core data or blocks a flow.
/// Silent unless a royal is equipped and Gamified Budgets is on; cameos also
/// respect the platform's reduce-motion setting and never interrupt a routine.
///
/// These full-body theatrics are OPT-IN: they only play when the "Enable Custom
/// Animations" preference ([AppPreferences.royalCustomAnimations]) is on (off by
/// default, toggled from the avatar picker). When it's off this whole host stays
/// dormant and the royal simply blinks and waves from the Home profile circle
/// (that idle loop lives in the circle avatar itself, not here).

const _ink = Color(0xFF15171E);

/// Anchor for the Home profile avatar, so the character can literally jump out
/// of and return into that circle. Attached by [HomeRewardsAvatar]. The circle
/// only counts while the Home tab is actually visible — on any other tab the
/// court's way home is the bottom bar's Home item instead (see
/// [_RoyalReactionHostState._anchorCenter]), so the royal never dives into a
/// corner that has no profile circle on the current screen.
final GlobalKey royalHomeAnchorKey = GlobalKey();

/// Anchor for the MONTHLY BUDGET gauge (the big progress ring on the Budgets
/// Overview tab, current month only). When the over-budget scold fires while
/// that ring is on screen, the royal runs in along the bottom, jumps up onto
/// the gauge and attacks IT — the thing that betrayed the budget — instead of
/// a generic spot near the bottom lane.
final GlobalKey royalBudgetChartAnchorKey = GlobalKey();

/// True while the character is "out" of the profile circle, so the Home avatar
/// can show an empty socket instead of doubling up. Cameos don't set this —
/// they wander in from off-screen, not out of the icon.
final ValueNotifier<bool> royalCharacterOut = ValueNotifier<bool>(false);

/// Watches the root navigator for modal POPUP routes — dialogs, bottom sheets,
/// menus, dropdowns — and reports whether any is currently on top.
///
/// The reaction host paints ABOVE the whole app (it wraps the Navigator in
/// `MaterialApp.builder`), so without this a screen attack in progress would
/// draw its shatter cracks and character straight over a sheet the user opens
/// mid-animation (e.g. Edit Budget) — and its haptics would keep firing under
/// the sheet. The host watches [popupOpen] and cleanly bows out the instant a
/// popup appears, and never starts a new flourish while one is up. It only
/// tracks [PopupRoute]s, so full-screen page pushes (which the court is allowed
/// to roam over) are unaffected. Registered in `MaterialApp.navigatorObservers`.
class RoyalOverlayRouteObserver extends NavigatorObserver {
  RoyalOverlayRouteObserver._();
  static final RoyalOverlayRouteObserver instance =
      RoyalOverlayRouteObserver._();

  final Set<Route<dynamic>> _popups = <Route<dynamic>>{};

  /// True while at least one modal popup route is on top of the app.
  final ValueNotifier<bool> popupOpen = ValueNotifier<bool>(false);

  void _recount() => popupOpen.value = _popups.isNotEmpty;

  void _add(Route<dynamic>? route) {
    if (route is PopupRoute) {
      _popups.add(route);
      _recount();
    }
  }

  void _remove(Route<dynamic>? route) {
    if (route != null && _popups.remove(route)) _recount();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _remove(oldRoute);
    _add(newRoute);
  }

  @visibleForTesting
  void debugReset() {
    _popups.clear();
    popupOpen.value = false;
  }
}

/// The ambient walk-on appearances the court makes between reactions.
enum RoyalCameo {
  /// A little stroll across the bottom of the current page, with a mid-way
  /// wave to the user.
  stroll,

  /// A full-tilt dash across the bottom on the royal's own ride.
  dash,

  /// Peeking in from a random screen edge, a look around, a wave, gone.
  peek,

  /// Popping up at a random safe spot for a two-hop celebration.
  twirl,
}

class _RoyalCameoEvent {
  final RoyalCameo cameo;
  final int nonce;
  const _RoyalCameoEvent(this.cameo, this.nonce);
}

final ValueNotifier<_RoyalCameoEvent?> _royalCameoRequest =
    ValueNotifier<_RoyalCameoEvent?>(null);
int _royalCameoNonce = 0;

/// Ask the court to play an ambient [cameo] now (subject to the same gates as
/// scheduled ones: royal equipped, gamified on, nothing already playing).
/// Fire-and-forget; used by the internal scheduler and by tests.
void requestRoyalCameo(RoyalCameo cameo) {
  _royalCameoRequest.value = _RoyalCameoEvent(cameo, ++_royalCameoNonce);
}

/// Watches financial-health snapshots and fires scold/cheer on meaningful
/// changes (over budget, or newly healthy).
///
/// The cheer is per-session and in-memory. The scold is driven by a
/// **persisted picture of which envelopes were over budget at the last
/// observation** ([_lastBreach]), and fires on every *crossing*: whenever the
/// live picture shows an envelope over budget that the remembered picture
/// doesn't (or a different month). That definition is what makes all of
/// these behave, where two earlier designs failed:
///
///  - reopening the app on a budget blown while it was closed → the stored
///    picture still says "within budget" → fires (the in-session-transition
///    design silently adopted "over" as its baseline here);
///  - reopening again on the SAME blown budget → stored picture already says
///    so → quiet (once per crossing, not once per launch);
///  - dropping back under and then going over again — same envelope, same
///    month → the under-budget observation cleared the stored picture, so
///    the second crossing fires (the once-per-signature design stayed
///    silent for the rest of the month);
///  - cutting the budget below what's already spent → a crossing with no new
///    charge → fires;
///  - a second envelope going over while the first is still blown → fires.
///
/// Still pure with respect to the database — the only thing it persists is
/// the one signature string, through [loadBreach]/[_persist].
class RoyalMood {
  RoyalMood._();

  static bool? _wasOverBudget;
  static bool? _wasHealthy;

  static bool _launchCheerDone = false;

  /// SharedPreferences key for [_lastBreach].
  static const String breachPrefsKey = 'royal_breach_state_v1';

  /// The pre-v1.59 key. It remembered only the last breach *scolded* — and
  /// was written at request time, so a reaction the host then dropped (gates
  /// off, royal still loading) still counted as delivered and silenced the
  /// month. Removed on load so no stale state lingers.
  static const String _legacyBreachKey = 'royal_scolded_breach_v1';

  /// Key for [_breachOwed].
  static const String owedPrefsKey = 'royal_breach_owed_v1';

  /// The breach state as of the last observation: a [breachSignature] while
  /// over budget, null while within. Persisted so it survives the app being
  /// closed — comparing the live picture against it is the crossing test.
  static String? _lastBreach;

  /// Whether a crossing has been detected but not yet *shown* to the user.
  ///
  /// The reaction is owed until it is actually delivered, and delivery only
  /// happens on the Budgets screen — the app no longer drags the user there,
  /// so the attack waits for them to open it themselves, however many
  /// launches later. Persisted for exactly that reason: a debt that expires
  /// when the app closes is the bug this whole area kept having.
  static bool _breachOwed = false;

  /// Whether the court still owes the user an over-budget reaction.
  static bool get breachOwed => _breachOwed;

  /// Load the remembered breach state. Called once at startup, before the
  /// first snapshot lands — without it every launch would re-fire for a
  /// breach the user has already been shown.
  static Future<void> loadBreach() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastBreach = prefs.getString(breachPrefsKey);
      _breachOwed = prefs.getBool(owedPrefsKey) ?? false;
      await prefs.remove(_legacyBreachKey);
    } catch (_) {
      // Cosmetic feature — a prefs failure must never break startup.
    }
  }

  static Future<void> _persist(String? signature) async {
    _lastBreach = signature;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (signature == null) {
        await prefs.remove(breachPrefsKey);
      } else {
        await prefs.setString(breachPrefsKey, signature);
      }
    } catch (_) {
      // Worst case the reaction repeats on the next launch.
    }
  }

  static Future<void> _setOwed(bool owed) async {
    if (_breachOwed == owed) return;
    _breachOwed = owed;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (owed) {
        await prefs.setBool(owedPrefsKey, true);
      } else {
        await prefs.remove(owedPrefsKey);
      }
    } catch (_) {
      // Worst case the reaction replays once on the next launch.
    }
  }

  /// The attack has been played — the debt is settled. Called by the host the
  /// moment the routine actually starts, never when it is merely requested.
  static void markBreachShown() => _setOwed(false);

  /// A stable id for "this particular over-budget situation": the month, plus
  /// every envelope currently blown. Null when nothing is over budget.
  ///
  /// Reopening the app on the same breach yields the same signature (so the
  /// court stays quiet); going over one MORE budget, or rolling into a new
  /// month, yields a different one and earns a fresh reaction.
  static String? breachSignature(FinancialHealth health, DateTime when) {
    final over = <String>[
      for (final b in health.budgets)
        if (b.isOver) (b.label ?? '#overall').toLowerCase(),
    ]..sort();
    if (over.isEmpty) return null;
    final month = '${when.year}-${when.month.toString().padLeft(2, '0')}';
    return '$month|${over.join(',')}';
  }

  /// Whether [current] contains a breach the remembered [prev] state hasn't
  /// covered: any envelope newly over budget, or a different month entirely.
  /// A *shrunken* set is not new — one budget recovering while another stays
  /// blown is old news, not a fresh crossing.
  static bool _isNewBreach(String? prev, String current) {
    if (prev == null || prev.isEmpty) return true;
    final p = prev.indexOf('|');
    final c = current.indexOf('|');
    if (p < 0 || c < 0) return true;
    if (prev.substring(0, p) != current.substring(0, c)) return true;
    final covered = prev.substring(p + 1).split(',').toSet();
    return current.substring(c + 1).split(',').any((e) => !covered.contains(e));
  }

  static void _scold(String signature) {
    _persist(signature);
    // Owed, not yet shown. The app deliberately does NOT navigate to the
    // Budgets tab: being thrown onto a screen you didn't ask for reads as
    // the app malfunctioning, not as feedback. The debt simply waits — the
    // attack plays the next time the user opens their budgets, which is
    // where it belongs and where they'll understand it.
    _setOwed(true);
    requestRoyalReaction(RoyalReaction.scold);
  }

  static void observe(FinancialHealth health, {DateTime? now}) {
    if (!health.hasScore) return;
    final signature = breachSignature(health, now ?? DateTime.now());
    final overBudget = signature != null;
    final band = health.band;
    final healthy = band == HealthBand.good || band == HealthBand.excellent;
    final firstThisSession = _wasOverBudget == null;

    if (overBudget) {
      if (_isNewBreach(_lastBreach, signature)) {
        // A crossing: an envelope is over that the remembered state didn't
        // have (or a new month). Fires on a cold start exactly like live —
        // the stored picture, not the session, is the baseline.
        _scold(signature);
      } else if (signature != _lastBreach) {
        // Same month, fewer envelopes over — nothing new to react to, but
        // remember the shrunken state so re-blowing one later counts as the
        // fresh crossing it is.
        _persist(signature);
      }
    } else {
      if (_lastBreach != null) {
        // Back within budget: clean slate. The next crossing fires even if
        // it's the same envelope in the same month — that's a new event to
        // the user, whatever the signature says.
        _persist(null);
      }
      if (healthy) {
        if (firstThisSession) {
          // A session that OPENS healthy and adherent gets the one launch
          // celebration (the host holds it until the welcome parade ends).
          if (!_launchCheerDone) {
            _launchCheerDone = true;
            requestRoyalReaction(RoyalReaction.cheer);
          }
        } else if (!(_wasHealthy ?? false)) {
          requestRoyalReaction(RoyalReaction.cheer);
        }
      }
    }
    _wasOverBudget = overBudget;
    _wasHealthy = healthy;
  }

  @visibleForTesting
  static void reset({String? lastBreach, bool breachOwed = false}) {
    _wasOverBudget = null;
    _wasHealthy = null;
    _launchCheerDone = false;
    _lastBreach = lastBreach;
    _breachOwed = breachOwed;
  }
}

/// The choreographed routines the character can perform. The first four are
/// icon-anchored reactions; the rest are ambient cameos.
enum _Routine { boot, smash, praise, strike, stroll, dash, peek, twirl }

/// How a royal makes its launch entrance.
///
/// The parade used to be one hardcoded path for all six — hop out, ride left,
/// turn, ride back, hop in — so every royal arrived identically, every
/// morning. The STYLE is now fixed per royal (that is the uniqueness) while
/// the DIRECTION and the far-point are sampled per launch (that is the
/// freshness). Style stays deterministic on purpose: a royal that entered
/// differently each time would have no signature at all.
enum _BootStyle {
  /// Out and back along the ground — the Prince's canter, the Medic's cart.
  parade,

  /// Out hard, a stomping halt at the far end that shakes the floor, then a
  /// charge home. The Dark Prince.
  chargeHalt,

  /// A rising arc out and a descending one back, never touching the floor.
  /// The Princess.
  soar,

  /// Covered in bursts: gone, a beat at the far side, gone again — the
  /// Sovereign outrunning the eye.
  blink,

  /// One long unhurried drift with no turnaround beat at all. The Empress.
  glide,
}

/// How a royal carries itself through an ambient cameo.
///
/// The four cameo routines used to be one choreography each, played identically
/// by all six: walk 45% and wave, ride straight across, slide in and wave,
/// pop in and cheer. Placement was already randomised ([_camDir], [_camA],
/// [_camB]) so no two cameos landed in the same spot — but every royal *behaved*
/// the same once it got there.
///
/// A manner is deliberately shared across all four routines rather than
/// bespoke per routine. A royal that stalks when it strolls but flits when it
/// peeks has no character; one that stalks everywhere does. [_Motion] already
/// tunes how each body carries itself — this is the choreography layer above it.
enum _Manner {
  /// Walks on, stops, waves, walks off. The Prince's parade manner, and the
  /// Medic's — both deliberately left as the baseline.
  brisk,

  /// Never stops and never quite lands: the Empress passes through rather than
  /// visiting, so she has no walk cycle and no pause at all.
  drift,

  /// Arrives and leaves between frames and holds perfectly still in between.
  /// The Sovereign.
  blink,

  /// Low and unhurried, with a long look before it leaves. The Dark Prince.
  stalk,

  /// Little airborne hops, coming to rest half a beat late. The Princess.
  flit,

  /// An even, unhurried march that comes to a dead stop and HOLDS it. The
  /// Sentinel is posted, not passing through: he is the only royal who stands
  /// still on purpose, and the stillness is the character.
  march,

  /// Low, fast, and never quite settled — in on a bound, a crouched beat, out
  /// again. The Huntress. Where the Empress drifts because she never lands,
  /// the Huntress lands hard and leaves immediately.
  pounce,
}

_Manner _mannerOf(String id) => switch (id) {
      'empress' => _Manner.drift,
      'sovereign' => _Manner.blink,
      'darkprince' => _Manner.stalk,
      'princess' => _Manner.flit,
      'sentinel' => _Manner.march,
      'huntress' => _Manner.pounce,
      _ => _Manner.brisk, // prince + royal medic, deliberately unchanged
    };

_BootStyle _bootStyleFor(String id) => switch (id) {
      'darkprince' => _BootStyle.chargeHalt,
      'princess' => _BootStyle.soar,
      'sovereign' => _BootStyle.blink,
      'empress' => _BootStyle.glide,
      // The Huntress bounds in like the Princess does — the difference is that
      // the Princess is carried and the Huntress jumps. Same entrance shape,
      // read apart by the body doing it.
      'huntress' => _BootStyle.soar,
      // The Sentinel keeps the parade: a guard marching on IS the baseline
      // this style was written for, so borrowing it is the right answer
      // rather than a shortcut.
      _ => _BootStyle.parade, // prince + apothecary + sentinel
    };

/// How long the welcome parade runs, per royal, in ms.
///
/// This used to be one flat number for the whole court, which quietly assumed
/// every royal signs off with the same amount of MOVEMENT. Six of them do —
/// a salute, a curtsy, a roar are each one gesture. The Huntress's is four
/// (throw, sweep-kick, catch, present) and she is also the only one who
/// somersaults across the screen on the way out, so the flat 5600 gave her
/// roughly 200ms a beat: too fast to read as anything but a flicker.
///
/// Only the two royals whose entrances actually carry more get an override.
/// The other six are deliberately untouched — their pacing is already the one
/// the court was tuned around.
/// One beat of parade choreography, in ms — the pace every royal moves at.
///
/// Taken from the court's own signature window (14% of 5600ms = 784ms for one
/// gesture) and rounded. A royal's TOTAL is not a taste decision: it falls out
/// of how many beats its choreography has. More beats means a longer parade,
/// never a slower one.
///
/// The Huntress is why this is written down. Her total was tuned twice while
/// the somersault was being restarted seven times a crossing, and both times
/// the answer was "give her more room" — ending at 12000ms, 2.1x the court.
/// With the restart fixed, that room turned into sluggishness: her rotation
/// ran at 1.59x the court's gesture and her signature beats at 1.15x. Pace is
/// the thing to hold constant; length is the thing that varies.
const int kParadeBeatMs = 800;

int _bootDurationMs(String id) => switch (id) {
      // Eight-and-a-bit beats: pop, a short wave (she is the one royal who
      // does not stop to be admired), two for the crossing, one for the blade
      // pivot, ~1.2 home, and FOUR for the signature, which is four separate
      // moves where the rest of the court signs off with one.
      'huntress' => 8400,
      // His signature is holding still, and stillness needs long enough to
      // read as deliberate rather than as the animation having stalled.
      'sentinel' => 6400,
      _ => 5600,
    };

/// Every beat of the parade, as fractions of the routine: pop out of the
/// circle, wave, ride out, turn at the far end, ride home, settle, sign off,
/// and hop back into the circle.
///
/// All of them are per-royal now, not just the late ones. Stretching the total
/// duration alone scales the greeting and the travel by exactly as much as the
/// move you actually wanted more of, so the Huntress's fix bought a slower
/// somersault at the price of a languid pop-out and a 1.8s wave. Her shape is
/// different from the court's: brisk on the way in, generous where the
/// choreography is.
typedef _BootBeats = ({
  double popEnd,
  double waveEnd,
  double outStart,
  double outEnd,
  double farEnd,
  double homeEnd,
  double sigStart,
  double sigEnd,
});

_BootBeats _bootBeatsFor(String id) => switch (id) {
      // Her parade is a ROUTE, not a lap: sprint out with one somersault in
      // it, land and turn with the blades up, sprint home, sign off. So the
      // Every span below is a whole number of [kParadeBeatMs], so nothing she
      // does runs at a different speed from the rest of the court — the
      // crossing is 2 beats with the rotation taking exactly 1 of them, the
      // pivot is 1, and the signature is 4 because it is four separate moves.
      //
      // She barely waves. She is the one member of the court who does not
      // stop to be admired, and a full-length wave was borrowed politeness.
      'huntress' => (
          popEnd: 0.06,
          waveEnd: 0.11,
          outStart: 0.13,
          outEnd: 0.32,
          farEnd: 0.42,
          homeEnd: 0.53,
          sigStart: 0.56,
          sigEnd: 0.94,
        ),
      'sentinel' => (
          popEnd: 0.09,
          waveEnd: 0.24,
          outStart: 0.29,
          outEnd: 0.50,
          farEnd: 0.55,
          homeEnd: 0.70,
          sigStart: 0.74,
          sigEnd: 0.92,
        ),
      _ => (
          popEnd: 0.09,
          waveEnd: 0.24,
          outStart: 0.29,
          outEnd: 0.50,
          farEnd: 0.55,
          homeEnd: 0.72,
          sigStart: 0.76,
          sigEnd: 0.90,
        ),
    };

/// The move a royal signs off its entrance with — how it says hello.
///
/// The parade already gave each royal its own way of crossing the screen, but
/// every one of them still ENDED on the same generic wave. The signature is
/// the beat the user actually remembers, so it belongs to the character: the
/// Empress conjures, the Princess blows a kiss, the Dark Prince plants his
/// club, the Sovereign's lion roars straight down the lens, the Medic takes
/// your vitals — which in a budgeting app is not only a joke, since the
/// Financial Health score is exactly a pulse reading — and the Prince salutes
/// with his new sword.
///
/// They are deliberately not all the same KIND of move: two are theatre (the
/// roar, the spell), two are affection (the kiss, the vitals), one is a threat
/// and one is drill. A court where everyone mugs at the camera the same way is
/// six copies of one idea.
///
/// [RoyalAction.wave] stays the fallback for any royal added later that has no
/// signature authored yet — better a plain hello than an assertion failure in
/// a cosmetic overlay.
///
/// Public because the avatar picker previews it before purchase: a buyer who
/// cannot see the move is being asked to pay for a description of it.
RoyalAction royalSignatureAction(String id) => switch (id) {
      'empress' => RoyalAction.spell,
      'princess' => RoyalAction.kiss,
      'darkprince' => RoyalAction.menace,
      'sovereign' => RoyalAction.roar,
      'royalmedic' => RoyalAction.mend,
      'prince' => RoyalAction.salute,
      'sentinel' => RoyalAction.brace,
      // She is the only royal with THREE moves of her own, because she is the
      // only one with no mount to carry a personality for her: the toss signs
      // off the entrance, the flying kick is her attack verb, and the blade
      // dance covers the cameos. The somersault is not in that list — it is
      // her traversal, the thing she does INSTEAD of riding, and using it as
      // the signature too would have made the whole entrance one move.
      'huntress' => RoyalAction.daggerToss,
      _ => RoyalAction.wave,
    };

/// Whether [a] is performed from the saddle (so the frame keeps the wide ride
/// box) rather than on foot.
bool royalActionIsMounted(RoyalAction a) =>
    a == RoyalAction.ride || a == RoyalAction.roar;

/// One frame of a routine: where the character is, what it's doing, and what
/// damage/projectiles are live on screen this instant.
class _CharFrame {
  final Offset center;
  final double scale;
  final RoyalAction action;
  final double actionT;
  final double facing;
  final double shake; // 0..1+ screen-shake intensity
  final List<_ImpactFx> impacts; // live shatter sites
  final List<_ProjFx> projectiles; // arrows / orbs in flight

  /// How solid the character is this frame. Below 1 only for the Sovereign's
  /// dash, where the body itself is what fades out (see [ghosts]).
  final double opacity;

  /// Afterimages of the character trailing the real one, nearest first.
  final List<_Ghost> ghosts;

  const _CharFrame({
    required this.center,
    required this.scale,
    required this.action,
    required this.actionT,
    required this.facing,
    this.shake = 0,
    this.impacts = const [],
    this.projectiles = const [],
    this.opacity = 1,
    this.ghosts = const [],
  });
}

/// One afterimage: the same pose, somewhere the character just was.
///
/// The Sovereign's entrance is meant to read as a man moving faster than the
/// eye follows — so during a dash the SOLID body drops to a smear and what you
/// actually see is the trail it left. Stretching each ghost horizontally is
/// what turns a row of copies into motion blur.
class _Ghost {
  final Offset center;
  final double opacity;
  final double stretch; // horizontal scale
  const _Ghost(this.center, this.opacity, this.stretch);
}

/// One live shatter site: where the blow landed, the direction it came in
/// from (orients gashes and embedded arrows), how far its bloom has run
/// (age 0→1 over the first beat) and the late fade-out.
class _ImpactFx {
  final Offset at;
  final double dir; // radians of the incoming attack
  final double age; // 0..1 bloom
  final double fade; // 1 → 0 as the damage heals off screen
  final int index; // per-routine ordinal (varies the geometry)
  const _ImpactFx({
    required this.at,
    required this.dir,
    required this.age,
    required this.fade,
    required this.index,
  });
}

enum _ProjKind { arrow, orb }

/// A projectile mid-flight, host-driven so it stays in lockstep with the pose.
class _ProjFx {
  final Offset at;
  final double dir; // travel direction, radians
  final _ProjKind kind;
  const _ProjFx({required this.at, required this.dir, required this.kind});
}

// Character boxes. Standing is a chibi portrait; riding gets a wide stage.
const double _cw = 78;
const double _ch = 100;
const double _rw = 150;
const double _rh = 96;

/// The two boxes a royal is drawn in, exported so anything previewing the
/// character outside this host (the avatar picker's stage) uses the same
/// proportions. A figure drawn in the wrong box does not just letterbox — the
/// rig lays a mount out horizontally against the width, so a ride squeezed
/// into the standing box comes out as a giant head on a pony.
const Size kRoyalStandBox = Size(_cw, _ch);
const Size kRoyalRideBox = Size(_rw, _rh);

/// Mounted in `MaterialApp.builder` (inside the app-lock gate). Loads the
/// equipped royal, plays a welcome routine once at launch, turns reaction
/// requests into full-body routines above the app, and schedules the rare
/// ambient cameos in between.
class RoyalReactionHost extends StatefulWidget {
  final Widget child;
  const RoyalReactionHost({super.key, required this.child});

  /// Test override for the ambient-cameo gap (defaults to minutes).
  /// The welcome parade's timing for [royalId], as the suite sees it: total
  /// length and how many ms the signature move actually gets. Exposed because
  /// "too fast to see" is a number, and a number can be pinned.
  @visibleForTesting
  static ({int totalMs, int signatureMs, int crossingMs, int rotationMs})
      debugBootTiming(String royalId) {
    final ms = _bootDurationMs(royalId);
    final b = _bootBeatsFor(royalId);
    final crossing = (b.outEnd - b.outStart) * ms;
    return (
      totalMs: ms,
      signatureMs: ((b.sigEnd - b.sigStart) * ms).round(),
      crossingMs: crossing.round(),
      // Wall-clock of one full somersault, for royals who cross on foot. This
      // is the number the pacing suite should hold, not the crossing length:
      // the crossing can be any length, but the ROTATION has to run at the
      // court's beat or she reads as slow next to everyone else.
      rotationMs: (crossing * kOnFootAirborneShare).round(),
    );
  }

  @visibleForTesting
  static Duration? debugCameoGap;

  @visibleForTesting
  static void debugReset() {
    _RoyalReactionHostState._bootedThisSession = false;
    royalCharacterOut.value = false;
    debugCameoGap = null;
    debugSmashParkPoll = null;
    debugSmashParkAttempts = null;
  }

  /// Test overrides for how a parked scold waits for the Budgets gauge: how
  /// often it re-checks, and how many checks before it plays anyway.
  @visibleForTesting
  static Duration? debugSmashParkPoll;

  @visibleForTesting
  static int? debugSmashParkAttempts;

  @override
  State<RoyalReactionHost> createState() => _RoyalReactionHostState();
}

class _RoyalReactionHostState extends State<RoyalReactionHost>
    with SingleTickerProviderStateMixin {
  RoyalAvatar? _royal;
  _Routine? _routine;
  _Routine? _pending; // one queued reaction, played after the current routine
  int _lastNonce = -1;
  int _lastCameoNonce = -1;
  double _durationMs = 1;
  static bool _bootedThisSession = false;

  final math.Random _rng = math.Random();

  /// Sampled per launch in [_play]: which way the boot parade sets off, and
  /// how far across the screen it goes. Keeps the same royal from replaying an
  /// identical entrance every morning. See [_BootStyle].
  double _bootDir = -1;
  double _bootReach = 0.42;
  Timer? _cameoTimer;
  DateTime _lastPlayEnd = DateTime.fromMillisecondsSinceEpoch(0);
  // Per-cameo randomness, rolled once when the cameo starts.
  double _camDir = 1;
  double _camA = 0.5;
  double _camB = 0.5;

  // Mirror of AppPreferences.royalCustomAnimations, so a mid-session toggle can
  // (re)start the parade/cameos when turned on and quiet them when turned off.
  bool _customAnimEnabled = false;

  // Attack bookkeeping, rolled fresh in _play: the normalized times each blow
  // lands (drives the haptics), how many have fired, the deterministic seed
  // the shatter geometry grows from, and — when the scold catches the user on
  // the Budgets tab — the category donut the attack should land on.
  List<double> _impactTimes = const [];
  int _impactsFired = 0;
  int _fxSeed = 0;
  Offset? _chartTarget;

  AppPreferences? _prefs;

  late final AnimationController _ctrl = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _endRoutine();
    })
    ..addListener(_tickImpactHaptics);

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_loadRoyal);
    royalReactionRequest.addListener(_onReaction);
    _royalCameoRequest.addListener(_onCameoRequest);
    mainShellTabIndex.addListener(_onTabChange);
    RoyalOverlayRouteObserver.instance.popupOpen.addListener(_onPopupChanged);
    _prefs = context.read<AppPreferences>()..addListener(_onPrefsChanged);
    _customAnimEnabled = _prefs!.royalCustomAnimations;
    _loadRoyal();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_loadRoyal);
    royalReactionRequest.removeListener(_onReaction);
    _royalCameoRequest.removeListener(_onCameoRequest);
    mainShellTabIndex.removeListener(_onTabChange);
    RoyalOverlayRouteObserver.instance.popupOpen
        .removeListener(_onPopupChanged);
    _prefs?.removeListener(_onPrefsChanged);
    _cameoTimer?.cancel();
    _parkedSmashTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  bool get _popupOpen => RoyalOverlayRouteObserver.instance.popupOpen.value;

  /// A modal popup (dialog, bottom sheet, menu) just opened or closed. The
  /// court never shares the screen with one: an in-flight flourish is bowed
  /// out cleanly the moment a popup appears (stopping its haptics too), and
  /// nothing new starts until it's gone.
  void _onPopupChanged() {
    if (!mounted) return;
    if (_popupOpen) {
      _cancelRoutine();
    } else if (!_bootedThisSession) {
      // The popup that was holding the entrance back has gone. Take it now
      // rather than waiting out the poll.
      _scheduleBoot();
    }
  }

  /// Abort the current routine immediately, without the tail effects a natural
  /// finish would run. Unlike [_endRoutine] it does NOT flush [_pending] — a
  /// queued reaction must not spring up over the popup that just cancelled us.
  void _cancelRoutine() {
    if (_routine == null) return;
    // Cancelling the welcome parade hands the entrance BACK. A session gets
    // exactly one, and a popup arriving a beat after launch — a rating prompt,
    // a restore, a tutorial step — used to spend it on a routine that was
    // then killed mid-stride, which is the other half of "the launch
    // animation sometimes doesn't play". _onPopupChanged re-schedules it once
    // the screen is free.
    if (_routine == _Routine.boot) _bootedThisSession = false;
    _ctrl.stop();
    _pending = null;
    royalCharacterOut.value = false;
    _lastPlayEnd = DateTime.now();
    if (mounted) setState(() => _routine = null);
  }

  /// Whether the equipped royal's full-body theatrics are enabled. The circle
  /// avatar's blink/wave is separate and always on — this only gates this host.
  bool get _customAnimations =>
      context.read<AppPreferences>().royalCustomAnimations;

  /// React to the "Enable Custom Animations" toggle flipping mid-session: on
  /// → run the welcome parade (if it hasn't yet) and resume ambient cameos;
  /// off → stop scheduling and drop any queued reaction (a routine already
  /// playing is left to finish on its own).
  void _onPrefsChanged() {
    if (!mounted) return;
    final on = _customAnimations;
    if (on == _customAnimEnabled) return;
    _customAnimEnabled = on;
    if (!on) {
      _cameoTimer?.cancel();
      // A queued smash survives the toggle flipping off — it's feedback,
      // not one of the decorations the toggle governs.
      if (_pending != _Routine.smash) _pending = null;
    } else if (_royal != null) {
      _scheduleBoot();
      _scheduleCameo();
    }
  }

  Future<void> _loadRoyal() async {
    final p = await GamificationService().loadProfile();
    final royal = royalAvatarAt(int.tryParse(p.avatarValue) ?? -1);
    if (!mounted) return;
    setState(() => _royal = royal);
    if (royal == null) {
      _cameoTimer?.cancel();
      return;
    }
    // A scold that arrived while the profile was still loading plays now —
    // and outranks the welcome parade, same as in _onReaction: the user is
    // being told they blew their budget, not welcomed.
    if (_pending == _Routine.smash &&
        _routine == null &&
        context.read<AppPreferences>().gamifiedMode) {
      _bootedThisSession = true;
      _pending = null;
      _startOrPark(_Routine.smash);
      _scheduleCameo();
      return;
    }
    // An attack owed from a previous launch, with the user already sitting on
    // Budgets when the profile finished loading.
    if (_owesSmash &&
        mainShellTabIndex.value == 1 &&
        _parkedSmashTimer == null &&
        context.read<AppPreferences>().gamifiedMode) {
      _bootedThisSession = true;
      _startSmashWatch();
    }
    // A one-time welcome when a royal is equipped and gamified is on — but only
    // once the Home profile icon is actually on screen, so the royal really
    // does jump out of that circle (not out of a splash/onboarding screen).
    if (!_bootedThisSession && context.read<AppPreferences>().gamifiedMode) {
      _scheduleBoot();
    }
    _scheduleCameo();
  }

  void _scheduleBoot([int attempts = 0]) {
    if (_bootedThisSession || !mounted) return;
    // Custom animations off: no welcome parade. Leave _bootedThisSession false
    // so turning it on later still gets the entrance (see _onPrefsChanged).
    if (!_customAnimations) return;
    // A modal owns the screen. This is the reason the parade "sometimes just
    // doesn't play": the session used to be marked booted here and _play then
    // refused silently for exactly this reason, burning the one entrance the
    // session gets on a frame that drew nothing. Anything modal up at launch
    // did it — a rating prompt, a restore, a tutorial step. Waiting costs
    // nothing, and _onPopupChanged nudges this the moment the popup closes.
    if (_popupOpen) {
      Future.delayed(const Duration(milliseconds: 200), () {
        // Deliberately does NOT advance `attempts`: the user may sit on a
        // dialog as long as they like, and the parade should still be waiting
        // on the other side of it.
        _scheduleBoot(attempts);
      });
      return;
    }
    if (royalHomeAnchorKey.currentContext != null && _routine == null) {
      _bootedThisSession = true;
      if (!_reduceMotion) {
        _play(_Routine.boot);
      } else {
        _playPending();
      }
      return;
    }
    if (attempts >= 40) {
      // ~8s: user never reached Home — skip the parade, but let a reaction
      // that queued up behind it (e.g. the launch cheer) still play.
      _bootedThisSession = true;
      _playPending();
      return;
    }
    Future.delayed(
        const Duration(milliseconds: 200), () => _scheduleBoot(attempts + 1));
  }

  void _onReaction() {
    final ev = royalReactionRequest.value;
    if (ev == null || ev.nonce == _lastNonce || !mounted) return;
    _lastNonce = ev.nonce;
    if (!context.read<AppPreferences>().gamifiedMode) return;
    final routine = switch (ev.reaction) {
      RoyalReaction.scold => _Routine.smash,
      RoyalReaction.cheer => _Routine.praise,
      RoyalReaction.taught => _Routine.praise,
      RoyalReaction.strike => _Routine.strike,
    };
    // The over-budget attack is FEEDBACK about the user's money; the parade,
    // cameos and cheers are decoration. Only the decoration sits behind the
    // "Enable Custom Animations" opt-in — that toggle defaults to off, and
    // gating the smash behind it made the flagship moment of Gamified
    // Budgets invisible to every user who never found the switch, which is
    // most of them.
    final isSmash = routine == _Routine.smash;
    if (!isSmash && !_customAnimations) return;
    // The equipped royal loads asynchronously at startup, and on a cold
    // start the scold can beat it here. Dropping the reaction lost it for
    // the whole session (the breach used to be marked handled anyway) —
    // queue it instead; _loadRoyal flushes the queue when the royal is in.
    if (_royal == null) {
      _pending = routine;
      return;
    }
    // A reaction that lands during another routine waits its turn instead of
    // being dropped — the launch cheer always arrives while the boot is
    // playing. Latest one wins.
    if (_routine != null) {
      _pending = routine;
      return;
    }
    if (!_bootedThisSession) {
      if (isSmash) {
        // Feedback outranks ceremony: skip the welcome parade rather than
        // holding the attack behind ~6s of pageantry — or forever, when
        // custom animations are off and the parade would never have run.
        _bootedThisSession = true;
      } else {
        _pending = routine;
        return;
      }
    }
    _startOrPark(routine);
  }

  /// Begin [r] now, unless it is the over-budget attack and the user isn't
  /// looking at their budgets — then let the debt stand.
  ///
  /// The attack wrecks the monthly-budget ring, so it only makes sense on the
  /// ring, and the app no longer drags anyone there to see it: being thrown
  /// onto a screen you didn't ask for reads as a malfunction. Instead the
  /// reaction stays owed ([RoyalMood.breachOwed], persisted) and is delivered
  /// the next time the user opens Budgets — this launch or a later one.
  void _startOrPark(_Routine r) {
    if (r == _Routine.smash && !_canStageSmash()) {
      _parkSmash();
      return;
    }
    _play(r);
  }

  /// Whether the attack can be staged right now: the user is on the Budgets
  /// tab, with the gauge laid out and no sheet over it.
  bool _canStageSmash() => !_popupOpen && _resolveChartTarget() != null;

  /// While the user is on Budgets, how often to re-check for the gauge and
  /// how many checks before giving up on it. The screen loads asynchronously
  /// and its ring needs a frame, so arrival and readiness aren't the same
  /// moment; ~4s covers the gap. Giving up doesn't lose the reaction — the
  /// debt is persisted and retried on the next visit.
  static const Duration _smashParkPoll = Duration(milliseconds: 300);
  static const int _smashParkAttempts = 14;

  Timer? _parkedSmashTimer;
  int _parkedSmashChecks = 0;

  /// This host's own record of an undelivered attack. [RoyalMood.breachOwed]
  /// is the durable one (it outlives the process); this covers a scold raised
  /// by any other route, so the host never depends on someone else's
  /// bookkeeping to remember what it still owes.
  bool _smashOwed = false;

  bool get _owesSmash => _smashOwed || RoyalMood.breachOwed;

  void _parkSmash() {
    _stopSmashWatch();
    _smashOwed = true;
    // Only worth watching while the user is actually on Budgets; landing
    // there later starts this again (see _onTabChange).
    if (mainShellTabIndex.value == 1) _startSmashWatch();
  }

  void _startSmashWatch() {
    _parkedSmashTimer?.cancel();
    _parkedSmashChecks = 0;
    _parkedSmashTimer = Timer.periodic(
      RoyalReactionHost.debugSmashParkPoll ?? _smashParkPoll,
      (_) => _pollParkedSmash(),
    );
  }

  void _pollParkedSmash() {
    if (!mounted) return;
    _parkedSmashChecks++;
    // Something else is playing (the launch parade, usually) — keep waiting
    // rather than stacking two routines on top of each other.
    if (_routine != null) return;
    if (_canStageSmash()) {
      _releaseParkedSmash();
      return;
    }
    // The user left Budgets, or the ring never appeared (they're on the
    // Categories sub-tab, or an older month). Stop looking — the debt is
    // persisted, so the next visit picks it up.
    final exhausted = _parkedSmashChecks >=
        (RoyalReactionHost.debugSmashParkAttempts ?? _smashParkAttempts);
    if (exhausted || mainShellTabIndex.value != 1) _stopSmashWatch();
  }

  void _stopSmashWatch() {
    _parkedSmashTimer?.cancel();
    _parkedSmashTimer = null;
    _parkedSmashChecks = 0;
  }

  void _releaseParkedSmash() {
    _stopSmashWatch();
    _smashOwed = false;
    _play(_Routine.smash);
  }

  void _playPending() {
    final p = _pending;
    if (p == null || !mounted || _routine != null) return;
    _pending = null;
    // A short beat between routines, so they read as separate thoughts. The
    // launch scold always arrives here (queued behind the welcome parade), so
    // it goes through the same gauge-seeking policy as a live one.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && _routine == null) _startOrPark(p);
    });
  }

  // ── Ambient cameo scheduling ────────────────────────────────────────────

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  Duration get _cameoGap =>
      RoyalReactionHost.debugCameoGap ??
      Duration(seconds: 110 + _rng.nextInt(150));

  void _scheduleCameo([Duration? gap]) {
    _cameoTimer?.cancel();
    if (_royal == null || !_customAnimations) return;
    _cameoTimer = Timer(gap ?? _cameoGap, _fireScheduledCameo);
  }

  void _fireScheduledCameo() {
    if (!mounted || _royal == null) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final away =
        lifecycle != null && lifecycle != AppLifecycleState.resumed;
    final keyboardUp =
        (MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0) > 0;
    if (away ||
        keyboardUp ||
        _routine != null ||
        _reduceMotion ||
        !_customAnimations ||
        !context.read<AppPreferences>().gamifiedMode) {
      _scheduleCameo(const Duration(seconds: 45)); // try again soon
      return;
    }
    final roll = _rng.nextDouble();
    requestRoyalCameo(roll < 0.30
        ? RoyalCameo.stroll
        : roll < 0.55
            ? RoyalCameo.dash
            : roll < 0.80
                ? RoyalCameo.peek
                : RoyalCameo.twirl);
    _scheduleCameo();
  }

  /// Landing on another tab occasionally invites a cameo there — that's what
  /// makes the court feel at home on every page, not just Home.
  void _onTabChange() {
    if (!mounted || _royal == null) return;
    // Opening Budgets is what an owed attack has been waiting for — possibly
    // since a previous launch. Start watching for the ring; the screen loads
    // asynchronously, so it won't be there on this frame.
    if (mainShellTabIndex.value == 1) {
      if (_owesSmash &&
          context.read<AppPreferences>().gamifiedMode &&
          _parkedSmashTimer == null) {
        _startSmashWatch();
      }
    } else {
      _stopSmashWatch();
    }
    if (_routine != null) return;
    if (!_customAnimations) return;
    if (DateTime.now().difference(_lastPlayEnd) <
        const Duration(seconds: 75)) {
      return;
    }
    if (_rng.nextDouble() >= 0.25) return;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _routine != null || _reduceMotion) return;
      requestRoyalCameo(
          _rng.nextBool() ? RoyalCameo.peek : RoyalCameo.stroll);
    });
  }

  void _onCameoRequest() {
    final ev = _royalCameoRequest.value;
    if (ev == null || ev.nonce == _lastCameoNonce || !mounted) return;
    _lastCameoNonce = ev.nonce;
    if (_royal == null || _routine != null) return;
    if (!context.read<AppPreferences>().gamifiedMode) return;
    if (!_customAnimations) return;
    _play(switch (ev.cameo) {
      RoyalCameo.stroll => _Routine.stroll,
      RoyalCameo.dash => _Routine.dash,
      RoyalCameo.peek => _Routine.peek,
      RoyalCameo.twirl => _Routine.twirl,
    });
  }

  void _play(_Routine r) {
    // Never begin a flourish over a modal popup — it would paint across the
    // dialog/sheet and rumble underneath it. (A popup opening mid-routine is
    // handled by _onPopupChanged, which cancels the one already playing.)
    if (_popupOpen) return;
    final weapon = _royal?.weapon ?? RoyalWeapon.sword;
    if (r == _Routine.boot) {
      // Sampled per launch, not per royal: which way they set off, and how far
      // they go. Enough that two mornings don't look like a replay, while the
      // style below keeps each royal recognisably itself.
      _bootDir = _rng.nextBool() ? -1.0 : 1.0;
      _bootReach = 0.34 + _rng.nextDouble() * 0.22; // 0.34–0.56 of the screen
    }
    _durationMs = switch (r) {
      _Routine.boot => _bootDurationMs(_royal?.id ?? ''),
      // Each weapon fights at its own tempo: the volley and the double-orb
      // barrage take longer than a single slam.
      _Routine.smash => _attackDurationMs(weapon),
      _Routine.praise => 3400, // cheer + victory twirl
      _Routine.strike => 2200,
      _Routine.stroll => 6500,
      _Routine.dash => 3000,
      _Routine.peek => 4200,
      _Routine.twirl => 3000,
    }
        .toDouble();
    _camDir = _rng.nextBool() ? 1 : -1;
    _camA = _rng.nextDouble();
    _camB = _rng.nextDouble();
    // Attack bookkeeping: when each blow lands (haptics), fresh shatter
    // geometry, and — resolved ONCE so mid-play scrolling can't drag the
    // damage around — the budget donut to aim at, when it's on screen.
    _impactTimes = switch (r) {
      _Routine.smash => _impactTimesFor(weapon),
      _Routine.strike => const [0.42],
      _ => const [],
    };
    _impactsFired = 0;
    _fxSeed = _rng.nextInt(1 << 30);
    _chartTarget = r == _Routine.smash ? _resolveChartTarget() : null;
    // The debt is settled when the attack actually starts — never when it is
    // merely requested. Marking it earlier is what used to lose the reaction
    // whenever a gate swallowed it.
    if (r == _Routine.smash) RoyalMood.markBreachShown();
    setState(() => _routine = r);
    if (!_isCameo(r)) royalCharacterOut.value = true;
    _ctrl
      ..duration = Duration(milliseconds: _durationMs.round())
      ..forward(from: 0);
  }

  /// How long each weapon's screen attack runs, in ms.
  static int _attackDurationMs(RoyalWeapon w) => switch (w) {
        RoyalWeapon.sword => 5200, // two crossing cuts
        RoyalWeapon.knightSword => 4800, // one driven slice
        RoyalWeapon.warClub => 5000, // slam + aftershock
        RoyalWeapon.bow => 5400, // three-arrow volley
        RoyalWeapon.orbs => 5400, // two hurled orbs
        RoyalWeapon.medKit => 4600, // kit slam + shock pulse
        RoyalWeapon.spear => 5000, // advance, thrust, recover
        RoyalWeapon.daggers => 5200, // three-cut flurry
      };

  /// The normalized routine times each blow lands. MUST stay in lockstep with
  /// the segment maths in [_attack] — the same numbers drive crack bloom,
  /// screen shake and the haptic schedule.
  static List<double> _impactTimesFor(RoyalWeapon w) => switch (w) {
        RoyalWeapon.sword => const [0.272, 0.432],
        RoyalWeapon.knightSword => const [0.366],
        RoyalWeapon.warClub => const [0.393, 0.47],
        RoyalWeapon.bow => const [0.296, 0.416, 0.536],
        RoyalWeapon.orbs => const [0.35, 0.53],
        RoyalWeapon.medKit => const [0.373],
        RoyalWeapon.spear => const [0.40], // one driven point
        RoyalWeapon.daggers => const [0.30, 0.39, 0.48], // fast, even flurry
      };

  /// Fires the physical feedback for each blow exactly when it lands.
  void _tickImpactHaptics() {
    if (_impactsFired >= _impactTimes.length) return;
    final r = _routine;
    if (r != _Routine.smash && r != _Routine.strike) return;
    while (_impactsFired < _impactTimes.length &&
        _ctrl.value >= _impactTimes[_impactsFired]) {
      final i = _impactsFired++;
      _fireImpactHaptic(_royal?.weapon ?? RoyalWeapon.sword, i,
          full: r == _Routine.smash);
    }
  }

  /// One blow's physical rumble. Two layers, both fire-and-forget:
  /// the `budgetify/rumble` channel drives the Android vibrator service
  /// directly (works even when the system touch-feedback setting is off —
  /// the reason the old impact-only haptics felt dead), and HapticFeedback
  /// adds the crisp transient on devices with rich haptics. Per-weapon
  /// waveforms: the club thuds twice, the kit double-pulses like a defib,
  /// arrows are short thunks, orbs boom.
  Future<void> _fireImpactHaptic(RoyalWeapon w, int index,
      {required bool full}) async {
    if (!full) {
      _rumble(const [0, 45], const [180]);
      await HapticFeedback.mediumImpact();
      return;
    }
    switch (w) {
      case RoyalWeapon.warClub:
        _rumble(const [0, 95, 55, 120], const [255, 210]);
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) await HapticFeedback.heavyImpact();
      case RoyalWeapon.sword:
      case RoyalWeapon.knightSword:
        _rumble(const [0, 55, 40, 75], const [235, 160]);
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 60));
        if (mounted) await HapticFeedback.mediumImpact();
      case RoyalWeapon.orbs:
        _rumble(const [0, 85, 45, 60], const [255, 120]);
        await HapticFeedback.heavyImpact();
      case RoyalWeapon.bow:
        _rumble(const [0, 35], const [210]);
        await HapticFeedback.mediumImpact();
      case RoyalWeapon.medKit:
        _rumble(const [0, 60, 70, 60], const [230, 230]);
        await HapticFeedback.heavyImpact();
      case RoyalWeapon.spear:
        // A point going through something: one hard punch, then the ring of
        // the shaft. Sharper than the club's thud and shorter than it.
        _rumble(const [0, 55, 30, 70], const [255, 130]);
        await HapticFeedback.heavyImpact();
      case RoyalWeapon.daggers:
        // Three quick ticks, not a thud.
        _rumble(const [0, 25, 30, 25], const [190, 170]);
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 45));
        if (mounted) await HapticFeedback.lightImpact();
    }
  }

  static const MethodChannel _rumbleChannel = MethodChannel('budgetify/rumble');

  /// Best-effort vibrator-service rumble; silently a no-op off-Android and in
  /// tests (missing plugin), so it can never break a cosmetic flow.
  void _rumble(List<int> pattern, List<int> amps) {
    _rumbleChannel.invokeMethod<void>(
        'rumble', {'pattern': pattern, 'amps': amps}).catchError((_) {});
  }

  /// The monthly budget gauge's centre, when the scold should land on it:
  /// only while the Budgets tab is the visible tab, nothing is pushed over
  /// the shell, and the ring is actually within the viewport. Null otherwise.
  Offset? _resolveChartTarget() {
    if (mainShellTabIndex.value != 1) return null;
    if (NotificationService.navigatorKey.currentState?.canPop() ?? false) {
      return null; // a detail screen covers the chart
    }
    final ro = royalBudgetChartAnchorKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return null;
    final c = ro.localToGlobal(ro.size.center(Offset.zero));
    final visible = c.dx > 40 &&
        c.dx < mq.size.width - 40 &&
        c.dy > mq.padding.top + 80 &&
        c.dy <
            mq.size.height -
                mq.padding.bottom -
                kBottomNavigationBarHeight -
                40;
    return visible ? c : null;
  }

  bool _isCameo(_Routine r) =>
      r == _Routine.stroll ||
      r == _Routine.dash ||
      r == _Routine.peek ||
      r == _Routine.twirl;

  void _endRoutine() {
    royalCharacterOut.value = false;
    _lastPlayEnd = DateTime.now();
    if (mounted) setState(() => _routine = null);
    _playPending();
  }

  // ── Frame maths ─────────────────────────────────────────────────────────

  /// Where the royal emerges from and returns to — aware of what's actually
  /// on the current screen. On the Home tab it's the profile circle itself.
  /// On any other tab the circle isn't visible (the IndexedStack keeps Home
  /// mounted, so its RenderBox still reports top-right coords — using them
  /// made the court dive into an empty corner); the believable way home from
  /// there is the bottom bar's HOME item (leftmost of the five tabs). With a
  /// route pushed over the shell, neither exists — top-right corner fallback.
  Offset _anchorCenter(Size screen, EdgeInsets pad) {
    final pushed =
        NotificationService.navigatorKey.currentState?.canPop() ?? false;
    if (!pushed && mainShellTabIndex.value == 0) {
      final ro = royalHomeAnchorKey.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        final pos = ro.localToGlobal(Offset.zero);
        return pos + Offset(ro.size.width / 2, ro.size.height / 2);
      }
    } else if (!pushed) {
      // First of five bottom-nav slots = the Home tab icon.
      return Offset(screen.width * 0.1,
          screen.height - pad.bottom - kBottomNavigationBarHeight * 0.55);
    }
    return Offset(screen.width - 34, pad.top + 26);
  }

  double _cyc(double t, double periodMs) => (t * _durationMs / periodMs) % 1;

  _CharFrame _frame(
          _Routine r, double t, Offset icon, Size screen, EdgeInsets pad) =>
      switch (r) {
        _Routine.boot => _boot(t, icon, screen),
        _Routine.smash => _attack(t, icon, screen, pad),
        _Routine.praise => _praise(t, icon, screen, pad),
        _Routine.strike => _strike(t, icon, screen, pad),
        _Routine.stroll => _stroll(t, screen, pad),
        _Routine.dash => _dash(t, screen, pad),
        _Routine.peek => _peek(t, screen),
        _Routine.twirl => _twirl(t, screen),
      };

  double _clampX(double x, Size s, [double half = _cw * 0.5]) =>
      x.clamp(half, s.width - half);

  /// The floor line shared by standing and riding boxes near the icon, so a
  /// royal that mounts up mid-routine doesn't hop levels.
  double _groundY(Offset icon) => icon.dy + _ch * 0.92;

  _CharFrame _boot(double t, Offset icon, Size screen) {
    final ground = _groundY(icon);
    final standY = ground - _ch * 0.5;
    final rideY = ground - _rh * 0.5;
    final style = _bootStyleFor(_royal?.id ?? '');
    final beats = _bootBeatsFor(_royal?.id ?? '');

    // How much room the ride box has either side of the start point. The
    // anchor is the Home profile circle, which lives in the TOP-RIGHT corner —
    // so "rightwards" is a few dozen pixels of runway, not half a screen.
    final half = _rw * 0.45;
    final startX = _clampX(icon.dx, screen, half);
    double runway(double d) =>
        d < 0 ? startX - half : (screen.width - half) - startX;

    // The far point used to be an absolute screen fraction (0.5 ± reach), not
    // a distance from home. Out of the top-right corner that put the far point
    // INBOARD of the start: a rightward parade travelled ~28px and came back,
    // which is why the Prince and Empress looked stuck in the corner for half
    // of all launches. Sample the direction, then honour it only if that side
    // actually has somewhere to go.
    var dir = _bootDir; // -1 sets off leftwards, +1 rightwards
    if (runway(dir) < runway(-dir) * 0.6) dir = -dir;
    final reach = math.min(screen.width * _bootReach, runway(dir));

    // The wave spot sits on the side they are about to travel toward, so the
    // hop out of the circle already commits to the direction.
    final waveC = Offset(_clampX(icon.dx + 30 * dir, screen), standY);
    final rideHomeC = Offset(waveC.dx, rideY);
    final farC =
        Offset(_clampX(startX + dir * reach, screen, half), rideY);

    // Facing follows travel: out is `dir`, home is `-dir`.
    final outFace = dir;
    final homeFace = -dir;

    /// Where the royal is at travel progress [p] (0 at home, 1 at the far
    /// point), for whichever leg is running. The styles differ ONLY here and
    /// in the beat at the far end — the pop-out, waves and hop-home are shared
    /// so every royal still reads as coming out of, and going back into, the
    /// same circle.
    Offset travel(double p, {required bool outbound}) {
      final a = outbound ? rideHomeC : farC;
      final b = outbound ? farC : rideHomeC;
      switch (style) {
        case _BootStyle.parade:
        case _BootStyle.chargeHalt:
          return _lerpO(a, b, Curves.easeInOut.transform(p));
        case _BootStyle.glide:
          // Linear: no acceleration anywhere in it. That absence is the whole
          // difference between drifting and being flung.
          return _lerpO(a, b, p);
        case _BootStyle.soar:
          // Rises on the way out, settles on the way back — a real arc, so she
          // is never on the floor at all.
          final base = _lerpO(a, b, Curves.easeInOut.transform(p));
          final arc = math.sin(p * math.pi) * _rh * (outbound ? 0.62 : 0.42);
          return base.translate(0, -arc);
        case _BootStyle.blink:
          // Three bursts with a held beat between each: covered ground appears
          // to happen between frames.
          final k = _blinkK(p);
          return _lerpO(a, b, k);
      }
    }

    /// The Sovereign's dash, as [_CharFrame] extras: during a burst the solid
    /// body all but disappears and a stretched trail of afterimages carries the
    /// motion instead. Holding still, everything returns to normal.
    ///
    /// Bursts used to be conveyed by position alone, which just looked like
    /// dropped frames — the eye reads a fully-drawn body appearing somewhere
    /// new as a teleport or a stutter, never as speed. Fading the body out is
    /// what makes it "too fast to see" rather than "skipping".
    ({double opacity, List<_Ghost> ghosts}) zip(
        double p, {required bool outbound}) {
      if (style != _BootStyle.blink) {
        return (opacity: 1.0, ghosts: const <_Ghost>[]);
      }
      final here = travel(p, outbound: outbound);
      // Speed from the curve itself, sampled rather than differentiated in
      // closed form — the burst curve changes and this keeps following it.
      final ahead = travel((p + 0.02).clamp(0.0, 1.0), outbound: outbound);
      final behind = travel((p - 0.02).clamp(0.0, 1.0), outbound: outbound);
      final v = (ahead - behind).distance / (screen.width * 0.055);
      final blur = v.clamp(0.0, 1.0);
      if (blur < 0.12) return (opacity: 1.0, ghosts: const <_Ghost>[]);
      final ghosts = <_Ghost>[
        for (var g = 1; g <= 4; g++)
          _Ghost(
            _lerpO(here, behind, g * 0.55),
            0.30 * blur / g,
            1 + blur * 0.55,
          ),
      ];
      // Fully solid until it starts moving, then gone: 1 → ~0.06.
      return (opacity: 1 - blur * 0.94, ghosts: ghosts);
    }

    if (t < beats.popEnd) {
      // Pop out of the icon with a little hop.
      final p = Curves.easeOutBack.transform(_seg(t, 0, beats.popEnd));
      final hop = -math.sin(_seg(t, 0, beats.popEnd) * math.pi) * 16;
      return _CharFrame(
          center: _lerpO(icon, waveC, p.clamp(0.0, 1.0)).translate(0, hop),
          scale: p.clamp(0.0, 1.0),
          action: RoyalAction.idle,
          actionT: _cyc(t, 1400),
          facing: outFace);
    }
    if (t < beats.waveEnd) {
      return _CharFrame(
          center: waveC,
          scale: 1,
          action: RoyalAction.wave,
          actionT: _seg(t, beats.popEnd, beats.waveEnd),
          facing: outFace);
    }
    if (t < beats.outStart) {
      // A beat before the mount appears.
      return _CharFrame(
          center: waveC,
          scale: 1,
          action: RoyalAction.idle,
          actionT: _cyc(t, 1400),
          facing: outFace);
    }
    if (t < beats.outEnd) {
      // Out across the screen on the royal ride.
      final p = _seg(t, beats.outStart, beats.outEnd);
      final fx = zip(p, outbound: true);
      return _CharFrame(
          center: travel(p, outbound: true),
          scale: 1,
          action: RoyalAction.ride,
          // The Empress's ride cycles slowly; the rest keep the brisk tempo.
          // The Huntress takes the leg's progress instead of a cycle, so the
          // crossing contains exactly one somersault.
          actionT: _rideIsOneShot
              ? p
              : _cyc(t, style == _BootStyle.glide ? 900 : 420),
          facing: outFace,
          opacity: fx.opacity,
          ghosts: fx.ghosts);
    }
    if (t < beats.farEnd) {
      // The beat at the far end, where each royal turns in its own way. The
      // Empress skips it entirely — she never stops, so there is nothing to
      // turn around; the glide just carries straight on into the return.
      final turned = style == _BootStyle.glide ? outFace : homeFace;
      if (_rideIsOneShot) {
        // She lands the vault and turns on the spot with the blades already
        // moving. This is the beat that says close combat rather than just
        // acrobatics — the somersault alone makes her a gymnast.
        //
        // A blade dance is not a mounted action, so it renders in the standing
        // box: hand it the standing lane's Y or she drops half a box height at
        // the turn (see [_groundY], which exists for exactly this).
        return _CharFrame(
            center: Offset(farC.dx, standY),
            scale: 1,
            action: RoyalAction.bladeDance,
            actionT: _seg(t, beats.outEnd, beats.farEnd),
            facing: turned);
      }
      return _CharFrame(
          center: style == _BootStyle.glide
              ? travel(1, outbound: true)
              : farC,
          scale: 1,
          action: RoyalAction.ride,
          // chargeHalt lands hard and holds; blink hangs a beat before going.
          actionT: _cyc(t, switch (style) {
            _BootStyle.chargeHalt => 240, // a short, heavy stamp in place
            _BootStyle.blink => 900,
            _ => 700,
          }),
          facing: turned);
    }
    if (t < beats.homeEnd) {
      final p = _seg(t, beats.farEnd, beats.homeEnd);
      final fx = zip(p, outbound: false);
      return _CharFrame(
          center: travel(p, outbound: false),
          scale: 1,
          action: RoyalAction.ride,
          // Above 1 is her sprint-only mode: she has already turned over once
          // on the way out, and doing it again on the way back is what made
          // the entrance read as tumbling rather than as a route being run.
          actionT: _rideIsOneShot
              ? 1.0 + p * 4
              : _cyc(t, style == _BootStyle.glide ? 900 : 420),
          facing: style == _BootStyle.glide ? outFace : homeFace,
          opacity: fx.opacity,
          ghosts: fx.ghosts);
    }

    // ── The signature ──────────────────────────────────────────────────────
    // Every royal used to end on the same wave here. Now each signs off in its
    // own way, and the Sovereign stays in the saddle for his, because the move
    // is the lion's (see [royalSignatureAction]).
    final sig = royalSignatureAction(_royal?.id ?? '');
    final mounted = royalActionIsMounted(sig);
    final sigC = mounted ? rideHomeC : waveC;
    // Facing: the signature is aimed at the USER, so the royal turns to the
    // roomier side of the screen rather than off the edge it came in from.
    final sigFace = waveC.dx > screen.width * 0.5 ? -1.0 : 1.0;

    if (t < beats.sigStart) {
      // Dismount / settle beat before the move.
      return _CharFrame(
          center: sigC,
          scale: 1,
          action: mounted ? RoyalAction.ride : RoyalAction.idle,
          actionT: _cyc(t, mounted ? 700 : 1400),
          facing: sigFace);
    }
    if (t < beats.sigEnd) {
      final at = _seg(t, beats.sigStart, beats.sigEnd);
      return _CharFrame(
          center: sigC,
          scale: 1,
          action: sig,
          actionT: at,
          facing: sigFace,
          // The roar hits the room: a short shake as the sound lands.
          shake: sig == RoyalAction.roar
              ? _seg(at, 0.16, 0.30) * (1 - _seg(at, 0.34, 0.62)) * 0.55
              : 0);
    }
    // A beat to dismount before diving home, so he doesn't take the lion in
    // through the profile circle with him.
    final dismountEnd = beats.sigEnd + 0.03;
    if (t < dismountEnd && mounted) {
      return _CharFrame(
          center: waveC,
          scale: 1,
          action: RoyalAction.idle,
          actionT: _cyc(t, 1400),
          facing: sigFace);
    }
    final p = _seg(t, mounted ? dismountEnd : beats.sigEnd, 1.0);
    final hop = -math.sin(p * math.pi) * 10;
    return _CharFrame(
        center: _lerpO(waveC, icon, Curves.easeIn.transform(p)).translate(0, hop),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: outFace);
  }

  /// The blink dash's travel curve: [steps] bursts, each covering its slot in
  /// the first fraction of the time available, then holding.
  static double _blinkK(double p, {int steps = 3}) {
    final seg = (p * steps).floor().clamp(0, steps - 1);
    final within = (p * steps) - seg;
    final eased = Curves.easeInExpo.transform(within.clamp(0.0, 1.0));
    return (seg + eased) / steps;
  }

  /// The stand line beside the anchor, kept on-screen even when the anchor is
  /// the bottom bar's Home slot (where the raw ground line would fall below
  /// the viewport).
  double _standYNear(Offset icon, Size screen, EdgeInsets pad) => math.min(
      _groundY(icon) - _ch * 0.5, _laneGround(screen, pad) - _ch * 0.5);

  /// Stage geometry for the screen attack: where the royal stands, where the
  /// blows land, and which way it faces. Locked to the monthly budget gauge
  /// when the scold caught the user in front of it (resolved once in
  /// [_play]); otherwise the classic spot along the anchor's stand line.
  ({Offset stage, Offset impact, double facing}) _arena(
      Offset icon, Size screen, EdgeInsets pad) {
    final w = _royal!.weapon;
    final ranged = w == RoyalWeapon.bow || w == RoyalWeapon.orbs;
    final target = _chartTarget;
    if (target != null) {
      final tgt = Offset(
        target.dx.clamp(70.0, screen.width - 70.0),
        target.dy.clamp(pad.top + 130.0, screen.height - pad.bottom - 190.0),
      );
      // Stand on the roomier side, facing the chart (+1 faces right).
      final side = tgt.dx >= screen.width * 0.5 ? -1.0 : 1.0;
      final stage = ranged
          ? Offset(_clampX(tgt.dx + side * 150, screen), tgt.dy + 26)
          : Offset(
              _clampX(tgt.dx + side * _cw * 0.42, screen), tgt.dy + _ch * 0.34);
      return (stage: stage, impact: tgt, facing: -side);
    }
    final standY = _standYNear(icon, screen, pad);
    if (ranged) {
      return (
        stage: Offset(_clampX(screen.width * 0.64, screen), standY),
        impact: Offset(screen.width * 0.30, standY + _ch * 0.06),
        facing: -1.0,
      );
    }
    final stage = Offset(_clampX(screen.width * 0.5, screen), standY);
    return (
      stage: stage,
      impact: stage + Offset(-_cw * 0.36, _ch * 0.34),
      facing: -1.0,
    );
  }

  /// The live shatter sites this frame: each blows in fast at its scheduled
  /// time and the whole damage heals off screen together late in the routine.
  List<_ImpactFx> _impactsFx(
      double t, List<double> times, List<Offset> at, List<double> dirs) {
    final fade = 1 - _seg(t, 0.76, 0.90);
    if (fade <= 0) return const [];
    final out = <_ImpactFx>[];
    for (var i = 0; i < times.length; i++) {
      final age = _seg(t, times[i], times[i] + 0.085);
      if (age <= 0) continue;
      out.add(
          _ImpactFx(at: at[i], dir: dirs[i], age: age, fade: fade, index: i));
    }
    return out;
  }

  /// Summed shake spikes, one per blow (heavier weapons hit harder).
  double _impactShake(double t, List<double> times, double amp) {
    var s = 0.0;
    for (final ti in times) {
      final k = _seg(t, ti, ti + 0.13);
      if (k > 0 && k < 1) s += 1 - Curves.easeOut.transform(k);
    }
    return (s * amp).clamp(0.0, 1.3);
  }

  /// The per-royal screen attack: same skeleton (pop out → close in → attack
  /// → fume → storm home), but every weapon fights its own way — the timings
  /// here MUST stay in lockstep with [_impactTimesFor].
  _CharFrame _attack(double t, Offset icon, Size screen, EdgeInsets pad) {
    final royal = _royal!;
    final w = royal.weapon;
    final arena = _arena(icon, screen, pad);
    final stage = arena.stage;
    final impact = arena.impact;
    final facing = arena.facing;
    final act = royalAttackActionFor(w);
    final times = _impactTimesFor(w);

    // Pop-out spot: beside the anchor, toward the stage, on a visible line.
    final outDir = (stage.dx - icon.dx).sign == 0 ? 1.0 : (stage.dx - icon.dx).sign;
    final outC = Offset(_clampX(icon.dx + 26 * outDir, screen),
        _standYNear(icon, screen, pad));
    final runFacing = (stage.dx - outC.dx).sign == 0 ? facing : (stage.dx - outC.dx).sign;

    // Blow sites + incoming directions, per weapon.
    final (List<Offset> pts, List<double> dirs) = switch (w) {
      RoyalWeapon.sword => (
          [impact, impact],
          [-0.62, 0.62], // two crossing diagonals → the X
        ),
      RoyalWeapon.knightSword => ([impact], [0.14]), // one near-horizontal gash
      RoyalWeapon.warClub => ([impact, impact], [math.pi / 2, math.pi / 2]),
      RoyalWeapon.bow => (
          [
            impact,
            impact + const Offset(-26, -18),
            impact + const Offset(24, 12),
          ],
          const [0.0, 0.0, 0.0], // filled in below from real flight paths
        ),
      RoyalWeapon.spear => ([impact], [0.0]), // one level puncture
      RoyalWeapon.daggers => (
          [impact, impact + const Offset(-18, -14), impact + const Offset(16, 10)],
          const [-0.70, 0.70, -0.20], // three crossing cuts
        ),
      RoyalWeapon.orbs => (
          [impact, impact + const Offset(30, -22)],
          const [0.0, 0.0],
        ),
      RoyalWeapon.medKit => ([impact], [math.pi / 2]),
    };

    // Ranged weapons: projectiles fly from the royal to each site.
    final muzzle = w == RoyalWeapon.bow
        ? stage + Offset(facing * _cw * 0.42, -_ch * 0.10)
        : stage + Offset(facing * _cw * 0.30, -_ch * 0.28);
    final resolvedDirs = (w == RoyalWeapon.bow || w == RoyalWeapon.orbs)
        ? [for (final p in pts) (p - muzzle).direction]
        : dirs;

    final proj = <_ProjFx>[];
    if (w == RoyalWeapon.bow) {
      const looses = [0.2664, 0.3864, 0.5064];
      for (var i = 0; i < 3; i++) {
        final p = _seg(t, looses[i], times[i]);
        if (p > 0 && p < 1) {
          proj.add(_ProjFx(
              at: _lerpO(muzzle, pts[i], p),
              dir: resolvedDirs[i],
              kind: _ProjKind.arrow));
        }
      }
    } else if (w == RoyalWeapon.orbs) {
      const releases = [0.29, 0.47];
      for (var i = 0; i < 2; i++) {
        final p = _seg(t, releases[i], times[i]);
        if (p > 0 && p < 1) {
          final arc = _lerpO(muzzle, pts[i], p)
              .translate(0, -math.sin(p * math.pi) * 70);
          proj.add(
              _ProjFx(at: arc, dir: resolvedDirs[i], kind: _ProjKind.orb));
        }
      }
    }

    final fx = _impactsFx(t, times, pts, resolvedDirs);
    final shakeAmp = switch (w) {
      RoyalWeapon.warClub => 1.0,
      RoyalWeapon.medKit => 0.8,
      RoyalWeapon.knightSword => 0.75,
      RoyalWeapon.sword => 0.7,
      RoyalWeapon.orbs => 0.6,
      RoyalWeapon.bow => 0.35,
      RoyalWeapon.spear => 0.7, // a puncture, not a body check
      RoyalWeapon.daggers => 0.45, // quick and light, never a thud
    };
    final shake = _impactShake(t, times, shakeAmp);

    _CharFrame cf(Offset center,
            {double scale = 1,
            RoyalAction? action,
            double? actionT,
            double? face}) =>
        _CharFrame(
          center: center,
          scale: scale,
          action: action ?? RoyalAction.idle,
          actionT: actionT ?? _cyc(t, 1400),
          facing: face ?? facing,
          shake: shake,
          impacts: fx,
          projectiles: proj,
        );

    // Entrance: pop out of the anchor, close in on the stage.
    final (double closeEnd, RoyalAction closeAct) = switch (w) {
      RoyalWeapon.warClub => (0.24, RoyalAction.walk), // heavy, unhurried
      RoyalWeapon.bow => (0.18, RoyalAction.walk), // light skip to range
      RoyalWeapon.orbs => (0.20, RoyalAction.walk), // a glide, never a run
      RoyalWeapon.medKit || RoyalWeapon.sword => (0.20, RoyalAction.run),
      RoyalWeapon.knightSword => (0.22, RoyalAction.run),
      // He does not run at things. A guard closes at a march, and arriving
      // unhurried is the most menacing thing about him.
      RoyalWeapon.spear => (0.26, RoyalAction.walk),
      RoyalWeapon.daggers => (0.16, RoyalAction.run), // in fast, low
    };
    // The knight's lunge carries him THROUGH the target; everyone else fights
    // on the spot.
    final preStage = w == RoyalWeapon.knightSword
        ? Offset(_clampX(stage.dx - facing * 120, screen), stage.dy)
        : stage;
    final postStage = w == RoyalWeapon.knightSword
        ? Offset(_clampX(stage.dx + facing * 140, screen), stage.dy)
        : stage;

    // When the attack targets the budget gauge, the stage floats mid-screen:
    // the royal runs in along the bottom lane and SPRINGS up onto the chart
    // (and hops back down after) instead of gliding through mid-air.
    final elevated = _chartTarget != null;
    final launch = Offset(
        _clampX(preStage.dx - runFacing * 46, screen), outC.dy);

    if (t < 0.07) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.07)).clamp(0.0, 1.0);
      return cf(_lerpO(icon, outC, p), scale: p, face: runFacing);
    }
    if (t < closeEnd) {
      if (elevated) {
        // Ground run to just under the chart, then the leap up onto it.
        final runEnd = 0.07 + (closeEnd - 0.07) * 0.55;
        if (t < runEnd) {
          final p = Curves.easeInOut.transform(_seg(t, 0.07, runEnd));
          return cf(_lerpO(outC, launch, p),
              action: RoyalAction.run,
              actionT: _cyc(t, 320),
              face: runFacing);
        }
        final p = _seg(t, runEnd, closeEnd);
        final rise = Curves.easeOutCubic.transform(p);
        // Parabolic overshoot above the straight path sells the spring.
        final hop = -math.sin(p * math.pi) *
            (52 + math.max(0, launch.dy - preStage.dy) * 0.18);
        return cf(_lerpO(launch, preStage, rise).translate(0, hop),
            face: facing);
      }
      final p = Curves.easeInOut.transform(_seg(t, 0.07, closeEnd));
      return cf(_lerpO(outC, preStage, p),
          action: closeAct,
          actionT: _cyc(t, closeAct == RoyalAction.run ? 320 : 480),
          face: runFacing);
    }

    // Attack + fume windows, per weapon.
    switch (w) {
      case RoyalWeapon.sword:
        if (t < 0.36) {
          return cf(stage, action: act, actionT: _seg(t, 0.20, 0.36));
        }
        if (t < 0.52) {
          return cf(stage, action: act, actionT: _seg(t, 0.36, 0.52));
        }
        if (t < 0.62) return cf(stage); // glare at the damage
        if (t < 0.80) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
      case RoyalWeapon.knightSword:
        if (t < 0.50) {
          final at = _seg(t, 0.22, 0.50);
          // Drive through the target during the pose's lunge (sub 0.30-0.60).
          final drive = _seg(at, 0.30, 0.60);
          return cf(_lerpO(preStage, postStage, Curves.easeInOut.transform(drive)),
              action: act, actionT: at);
        }
        if (t < 0.60) return cf(postStage); // skid, look back at the cut
        if (t < 0.80) {
          return cf(postStage,
              action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
      case RoyalWeapon.warClub:
        if (t < 0.54) {
          return cf(stage, action: act, actionT: _seg(t, 0.24, 0.54));
        }
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 640));
        }
      case RoyalWeapon.bow:
        if (t < 0.30) {
          return cf(stage, action: act, actionT: _seg(t, 0.18, 0.30));
        }
        if (t < 0.42) {
          return cf(stage, action: act, actionT: _seg(t, 0.30, 0.42));
        }
        if (t < 0.54) {
          return cf(stage, action: act, actionT: _seg(t, 0.42, 0.54));
        }
        if (t < 0.64) return cf(stage); // lower the bow, admire the grouping
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
      case RoyalWeapon.orbs:
        if (t < 0.38) {
          return cf(stage, action: act, actionT: _seg(t, 0.20, 0.38));
        }
        if (t < 0.56) {
          return cf(stage, action: act, actionT: _seg(t, 0.38, 0.56));
        }
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 800));
        }
      case RoyalWeapon.medKit:
        if (t < 0.52) {
          return cf(stage, action: act, actionT: _seg(t, 0.22, 0.52));
        }
        if (t < 0.80) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
      case RoyalWeapon.spear:
        // One driven thrust, then he holds the brace rather than gloating —
        // the guard does not celebrate, and he does not lose his temper about
        // it either, so he braces where the others fume.
        if (t < 0.58) {
          return cf(stage, action: act, actionT: _seg(t, 0.26, 0.58));
        }
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.brace, actionT: _seg(t, 0.58, 0.82));
        }
      case RoyalWeapon.daggers:
        // Three cuts back to back, no pause between them.
        if (t < 0.34) {
          return cf(stage, action: act, actionT: _seg(t, 0.22, 0.34));
        }
        if (t < 0.43) {
          return cf(stage, action: act, actionT: _seg(t, 0.34, 0.43));
        }
        if (t < 0.54) {
          return cf(stage, action: act, actionT: _seg(t, 0.43, 0.54));
        }
        if (t < 0.62) return cf(stage); // a beat, blades still out
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 600));
        }
    }

    // Storm home: (hop off the chart, then) run back to the pop spot and
    // dive into the anchor — the same circle/slot the royal came out of.
    final backStart = switch (w) {
      RoyalWeapon.warClub ||
      RoyalWeapon.bow ||
      RoyalWeapon.orbs ||
      RoyalWeapon.spear ||
      RoyalWeapon.daggers =>
        0.82,
      _ => 0.80,
    };
    final from = w == RoyalWeapon.knightSword ? postStage : stage;
    if (t < 0.93) {
      if (elevated) {
        // Hop down from the chart to the bottom lane...
        final land = Offset(
            _clampX(from.dx - runFacing * 52, screen), outC.dy);
        final downEnd = backStart + (0.93 - backStart) * 0.42;
        if (t < downEnd) {
          final p = _seg(t, backStart, downEnd);
          final drop = Curves.easeInCubic.transform(p);
          final hop = -math.sin(p * math.pi) * 30;
          return cf(_lerpO(from, land, drop).translate(0, hop),
              face: -runFacing);
        }
        // ...then run home along it.
        final p = Curves.easeInOut.transform(_seg(t, downEnd, 0.93));
        final backFacing =
            (outC.dx - land.dx).sign == 0 ? -runFacing : (outC.dx - land.dx).sign;
        return cf(_lerpO(land, outC, p),
            action: RoyalAction.run, actionT: _cyc(t, 320), face: backFacing);
      }
      final p = Curves.easeInOut.transform(_seg(t, backStart, 0.93));
      final backFacing = (outC.dx - from.dx).sign == 0 ? -facing : (outC.dx - from.dx).sign;
      return cf(_lerpO(from, outC, p),
          action: RoyalAction.run, actionT: _cyc(t, 320), face: backFacing);
    }
    final p = _seg(t, 0.93, 1.0);
    return cf(_lerpO(outC, icon, Curves.easeIn.transform(p)),
        scale: (1 - p).clamp(0.0, 1.0), face: -runFacing);
  }

  _CharFrame _praise(double t, Offset icon, Size screen, EdgeInsets pad) {
    final showC = Offset(
        _clampX(icon.dx - 28, screen), _standYNear(icon, screen, pad));
    if (t < 0.10) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.10)).clamp(0.0, 1.0);
      return _CharFrame(
          center: _lerpO(icon, showC, p), scale: p, action: RoyalAction.cheer, actionT: 0, facing: -1);
    }
    if (t < 0.42) {
      return _CharFrame(
          center: showC, scale: 1, action: RoyalAction.cheer, actionT: _cyc(t, 800), facing: -1);
    }
    if (t < 0.58) {
      // A victory twirl: the royal spins in place (rapid facing flips read as
      // a spin at chibi scale), arms and weapon still raised.
      final flips = (t * _durationMs / 130).floor();
      return _CharFrame(
          center: showC,
          scale: 1,
          action: RoyalAction.cheer,
          actionT: _cyc(t, 800),
          facing: flips.isEven ? -1 : 1);
    }
    if (t < 0.86) {
      return _CharFrame(
          center: showC, scale: 1, action: RoyalAction.cheer, actionT: _cyc(t, 800), facing: -1);
    }
    final p = _seg(t, 0.86, 1.0);
    return _CharFrame(
        center: _lerpO(showC, icon, Curves.easeIn.transform(p)),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: -1);
  }

  _CharFrame _strike(double t, Offset icon, Size screen, EdgeInsets pad) {
    final showC = Offset(
        _clampX(icon.dx - 28, screen), _standYNear(icon, screen, pad));
    // Each royal vanquishes with its own weapon verb (no screen damage here —
    // the deleted transaction is the victim, not the glass).
    final act = royalAttackActionFor(_royal?.weapon ?? RoyalWeapon.sword);
    if (t < 0.14) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.14)).clamp(0.0, 1.0);
      return _CharFrame(
          center: _lerpO(icon, showC, p), scale: p, action: RoyalAction.idle, actionT: 0, facing: -1);
    }
    if (t < 0.68) {
      final at = _seg(t, 0.14, 0.68);
      return _CharFrame(
          center: showC,
          scale: 1,
          action: act,
          actionT: at,
          facing: -1,
          shake: _seg(t, 0.36, 0.42) * (1 - _seg(t, 0.42, 0.58)) * 0.4);
    }
    final p = _seg(t, 0.68, 1.0);
    return _CharFrame(
        center: _lerpO(showC, icon, Curves.easeIn.transform(p)),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: -1);
  }

  /// The walking lane: just above the bottom navigation bar.
  double _laneGround(Size screen, EdgeInsets pad) =>
      screen.height - pad.bottom - kBottomNavigationBarHeight - 4;

  // ── Cameo manner ─────────────────────────────────────────────────────────
  // The four helpers every cameo routine consults, so a royal moves like
  // itself whichever routine happens to fire. See [_Manner].

  _Manner get _manner => _mannerOf(_royal?.id ?? '');

  /// Vertical offset over the life of a cameo — how far off the floor this
  /// royal is at [t], as a fraction of character height.
  double _mannerLift(double t) {
    final cyc = t * 2 * math.pi;
    return switch (_manner) {
      // Floats throughout, breathing slowly. Never touches down.
      _Manner.drift => -_ch * (0.16 + 0.028 * math.sin(cyc * 2)),
      // Hops: quick little arcs, feet meeting the floor between each.
      _Manner.flit => -_ch * 0.075 * math.sin(cyc * 6).abs(),
      // Long, low bounds — further than the Princess's hops and half as often,
      // so it reads as covering ground rather than skipping.
      _Manner.pounce => -_ch * 0.14 * math.sin(cyc * 3).abs(),
      // Both feet on the floor, always. A sentry does not bob.
      _Manner.brisk || _Manner.blink || _Manner.stalk || _Manner.march => 0,
    };
  }

  /// Travel easing. Blink covers ground in bursts; stalk builds slowly; drift
  /// never accelerates at all.
  double _mannerTravel(double p) {
    switch (_manner) {
      case _Manner.brisk:
        return p;
      case _Manner.drift:
        return p; // linear: the absence of acceleration IS the elegance
      case _Manner.stalk:
        return Curves.easeInCubic.transform(p);
      case _Manner.flit:
        return Curves.easeInOutSine.transform(p);
      case _Manner.march:
        return p; // metronomic — no acceleration anywhere in it
      case _Manner.pounce:
        return Curves.easeOutQuart.transform(p); // all the speed up front
      case _Manner.blink:
        const steps = 3;
        final seg = (p * steps).floor().clamp(0, steps - 1);
        final within = (p * steps) - seg;
        return (seg + Curves.easeInExpo.transform(within.clamp(0.0, 1.0))) /
            steps;
    }
  }

  /// Milliseconds per locomotion cycle, scaled off a routine's [base] tempo.
  double _mannerTempo(double base) => base *
      switch (_manner) {
        _Manner.brisk => 1.0,
        _Manner.drift => 1.9, // unhurried
        _Manner.blink => 1.4,
        _Manner.stalk => 1.45, // heavy on his feet
        _Manner.flit => 0.78, // light and quick
        _Manner.march => 1.55, // measured, and slower than the Prince's parade
        _Manner.pounce => 0.66, // the quickest feet in the court
      };

  /// What this royal does while travelling. The Empress has no walk cycle —
  /// legs pumping under a gown that never lands reads as a glitch, not a glide.
  RoyalAction get _mannerWalk =>
      _manner == _Manner.drift ? RoyalAction.idle : RoyalAction.walk;

  /// Whether this royal stops to wave mid-cameo. The Empress never stops, and
  /// the Dark Prince does not wave at anybody.
  /// Whether this royal stops to wave mid-cameo. The Empress never stops, the
  /// Dark Prince does not wave at anybody, and the Sentinel will not break post
  /// to acknowledge you — he halts, faces front, and that is all you get.
  bool get _mannerGreets =>
      _manner != _Manner.drift &&
      _manner != _Manner.stalk &&
      _manner != _Manner.march;

  /// How this royal says hello mid-cameo. Everyone waves; the Huntress plays
  /// with her knives instead.
  ///
  /// She is the third slot of a three-move set — the launch entrance signs off
  /// with the dagger toss, screen attacks go through the flying kick, and this
  /// is the one that has to work in a cameo, where she appears mid-screen with
  /// no runway to leap from. Feet planted, all wrists: it is the only one of
  /// the three that fits in a standing box.
  /// Whether this royal's "ride" is a one-shot traversal rather than a looping
  /// gait — true only for the Huntress, who has no mount.
  ///
  /// A gallop repeats, so the host drives it with a fast repeating cycle and a
  /// longer crossing just means more strides. Her crossing is a SEQUENCE (run,
  /// one somersault, land, run), and feeding a sequence the same repeating
  /// cycle restarted it about seven times per leg. Her ride takes the leg's own
  /// progress instead — see `_rideOnFoot`.
  bool get _rideIsOneShot => _royal?.id == 'huntress';

  RoyalAction get _mannerGreetAction => _royal?.id == 'huntress'
      ? RoyalAction.bladeDance
      : RoyalAction.wave;

  /// The held celebratory beat (the twirl cameo, the reward routines). The
  /// generic cheer pops stars and hearts around the head, which is a fine
  /// party trick for most of the court and completely wrong for the outlaw.
  RoyalAction get _mannerCheerAction => _royal?.id == 'huntress'
      ? RoyalAction.bladeDance
      : RoyalAction.cheer;

  _CharFrame _stroll(double t, Size screen, EdgeInsets pad) {
    const scale = 0.85;
    final y = _laneGround(screen, pad) - _ch * scale * 0.5;
    final dir = _camDir;
    final fromX = dir > 0 ? -_cw * 0.6 : screen.width + _cw * 0.6;
    final toX = dir > 0 ? screen.width + _cw * 0.6 : -_cw * 0.6;
    final lift = _mannerLift(t);
    final tempo = _mannerTempo(480);

    // Royals who never stop simply cross, with no mid-beat to break the line.
    if (!_mannerGreets) {
      return _CharFrame(
          center: Offset(_lerp(fromX, toX, _mannerTravel(t)), y + lift),
          scale: scale,
          // The Dark Prince still walks — he just doesn't greet anyone. The
          // Empress has no walk at all.
          action: _manner == _Manner.stalk || _manner == _Manner.march
              ? RoyalAction.walk
              : _mannerWalk,
          actionT: _cyc(t, tempo),
          facing: dir);
    }

    // Travel 45% of the way, pause, travel off.
    final waveX = _lerp(fromX, toX, 0.45);
    if (t < 0.40) {
      final p = _mannerTravel(_seg(t, 0, 0.40));
      return _CharFrame(
          center: Offset(_lerp(fromX, waveX, p), y + lift),
          scale: scale,
          action: _mannerWalk,
          actionT: _cyc(t, tempo),
          facing: dir);
    }
    if (t < 0.58) {
      return _CharFrame(
          center: Offset(waveX, y + lift),
          scale: scale,
          action: _mannerGreetAction,
          actionT: _seg(t, 0.40, 0.58),
          facing: dir);
    }
    final p = _mannerTravel(_seg(t, 0.58, 1.0));
    return _CharFrame(
        center: Offset(_lerp(waveX, toX, p), y + lift),
        scale: scale,
        action: _mannerWalk,
        actionT: _cyc(t, tempo),
        facing: dir);
  }

  _CharFrame _dash(double t, Size screen, EdgeInsets pad) {
    const scale = 0.9;
    final y = _laneGround(screen, pad) - _rh * scale * 0.5;
    final dir = _camDir;
    final fromX = dir > 0 ? -_rw * 0.6 : screen.width + _rw * 0.6;
    final toX = dir > 0 ? screen.width + _rw * 0.6 : -_rw * 0.6;
    // The mount already differs per royal; this makes the PATH differ too, so
    // a dash isn't the same straight line under six different animals.
    final p = _manner == _Manner.brisk
        ? Curves.easeInOutSine.transform(t)
        : _mannerTravel(t);
    // The flier arcs across rather than crossing flat; the drifter sinks a
    // little as it passes, the way something unhurried does.
    final arc = switch (_manner) {
      _Manner.flit => -math.sin(t * math.pi) * _rh * 0.30,
      _Manner.drift => -_rh * 0.10 + math.sin(t * math.pi) * _rh * 0.06,
      _ => 0.0,
    };
    return _CharFrame(
        center: Offset(_lerp(fromX, toX, p), y + arc),
        scale: scale,
        action: RoyalAction.ride,
        // One somersault per cameo crossing, for the same reason as the
        // parade: her ride is a sequence, not a cycle.
        actionT: _rideIsOneShot ? t : _cyc(t, _mannerTempo(400)),
        facing: dir);
  }

  _CharFrame _peek(double t, Size screen) {
    final side = _camDir; // +1 = right edge, -1 = left edge
    final y = _lerp(screen.height * 0.24, screen.height * 0.58, _camA);
    final hiddenX =
        side > 0 ? screen.width + _cw * 0.55 : -_cw * 0.55;
    final shownX =
        side > 0 ? screen.width - _cw * 0.10 : _cw * 0.10;
    final facing = -side; // look into the screen
    // Entry and exit carry the manner: the Sovereign is simply there, the Dark
    // Prince leans in slowly, everyone else slides.
    final inCurve = switch (_manner) {
      _Manner.blink => Curves.easeInExpo, // almost a cut
      _Manner.stalk => Curves.easeInOutCubic, // a slow lean
      _ => Curves.easeOutCubic,
    };
    final outCurve =
        _manner == _Manner.blink ? Curves.easeOutExpo : Curves.easeInCubic;
    final lift = _mannerLift(t);

    double x;
    RoyalAction action = RoyalAction.idle;
    double actionT = _cyc(t, _mannerTempo(1400));
    if (t < 0.15) {
      x = _lerp(hiddenX, shownX, inCurve.transform(_seg(t, 0, 0.15)));
    } else if (t < 0.55) {
      x = shownX;
    } else if (t < 0.75) {
      x = shownX;
      // The ones who don't greet just watch, and the held look is the point.
      if (_mannerGreets) {
        action = _mannerGreetAction;
        actionT = _seg(t, 0.55, 0.75);
      }
    } else if (t < 0.85) {
      x = shownX;
    } else {
      x = _lerp(shownX, hiddenX, outCurve.transform(_seg(t, 0.85, 1)));
    }
    return _CharFrame(
        center: Offset(x, y + lift),
        scale: 1,
        action: action,
        actionT: actionT,
        facing: facing);
  }

  _CharFrame _twirl(double t, Size screen) {
    const scale = 0.8;
    final spot = Offset(_lerp(screen.width * 0.25, screen.width * 0.75, _camA),
        _lerp(screen.height * 0.30, screen.height * 0.52, _camB));
    final facing = _camDir;
    final lift = _mannerLift(t);
    final tempo = _mannerTempo(800);
    // The Sovereign snaps into place; the Dark Prince arrives without any
    // flourish at all; the rest keep the springy pop.
    final popIn = switch (_manner) {
      _Manner.blink => Curves.easeOutExpo,
      _Manner.stalk => Curves.easeOutCubic,
      _ => Curves.easeOutBack,
    };
    if (t < 0.14) {
      final p = popIn.transform(_seg(t, 0, 0.14));
      return _CharFrame(
          center: spot.translate(0, lift),
          scale: scale * p.clamp(0.0, 1.15),
          action: _mannerCheerAction,
          actionT: 0,
          facing: facing);
    }
    if (t < 0.86) {
      return _CharFrame(
          center: spot.translate(0, lift),
          scale: scale,
          action: _mannerCheerAction,
          actionT: _cyc(t, tempo),
          facing: facing);
    }
    final p = 1 - _seg(t, 0.86, 1.0);
    return _CharFrame(
        center: spot.translate(0, lift),
        scale: scale * Curves.easeIn.transform(p),
        action: _mannerCheerAction,
        actionT: _cyc(t, tempo),
        facing: facing);
  }

  Offset _shake(double s) {
    final e = _ctrl.value * _durationMs;
    return Offset(math.sin(e * 0.09) * 10, math.cos(e * 0.13) * 7) * s;
  }

  @override
  Widget build(BuildContext context) {
    final gamified = context.watch<AppPreferences>().gamifiedMode;
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final royal = _royal;
        final routine = _routine;
        if (routine == null || royal == null || !gamified) return child!;
        // Defensive: a popup on top means the overlay must not paint (the
        // routine is normally already cancelled by _onPopupChanged; this also
        // covers the single frame between the push and that callback).
        if (_popupOpen) return child!;

        final mq = MediaQuery.of(context);
        final icon = _anchorCenter(mq.size, mq.padding);
        final f = _frame(routine, _ctrl.value, icon, mq.size, mq.padding);
        final shakeOff = f.shake > 0 ? _shake(f.shake) : Offset.zero;
        final wide = royalActionIsMounted(f.action);
        final boxW = wide ? _rw : _cw;
        final boxH = wide ? _rh : _ch;

        /// One draw of the character — the real one, or an afterimage.
        Widget figure(Offset center,
                {required double opacity, double stretch = 1}) =>
            Positioned(
              left: center.dx - boxW / 2,
              top: center.dy - boxH / 2,
              width: boxW,
              height: boxH,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scaleX: f.scale * stretch,
                    scaleY: f.scale,
                    child: CustomPaint(
                      painter: RoyalCharacterPainter(
                        royal: royal,
                        action: f.action,
                        t: f.actionT,
                        facing: f.facing,
                      ),
                    ),
                  ),
                ),
              ),
            );

        return Stack(
          children: [
            Transform.translate(offset: shakeOff, child: child),
            if (f.impacts.isNotEmpty || f.projectiles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShatterPainter(
                      weapon: royal.weapon,
                      accent: royal.theme.accent,
                      impacts: f.impacts,
                      projectiles: f.projectiles,
                      seed: _fxSeed,
                    ),
                  ),
                ),
              ),
            // Afterimages first (furthest back last in the list, so they paint
            // under the real body).
            for (final g in f.ghosts.reversed)
              figure(g.center, opacity: g.opacity, stretch: g.stretch),
            figure(f.center, opacity: f.opacity),
          ],
        );
      },
    );
  }
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _lerp(double a, double b, double x) => a + (b - a) * x;
Offset _lerpO(Offset a, Offset b, double x) =>
    Offset(_lerp(a.dx, b.dx, x), _lerp(a.dy, b.dy, x));

/// Full-screen damage for the royal attacks — the "they really shattered our
/// screen" pass. Layered per blow: an impact flash + shockwave ring, weapon-
/// specific fracture geometry (deterministic from [seed], so nothing flickers
/// between frames), glass shards thrown out with a touch of gravity, and a
/// light-loss vignette that gives the hit physical weight. Everything fades
/// out together late in the routine as the damage "heals".
///
/// Per weapon: the sword of state rips two crossing diagonal gashes (an X),
/// the knight's lunge drags one long near-horizontal gash with sparks along
/// it (the cut a thrust-and-draw leaves), the war club blows a
/// full spiderweb crater that keeps propagating after the hit, arrows punch
/// small dense webs and stay embedded (quivering), orbs detonate in accent-
/// tinted shock rings with rising embers, the med kit slams a spiderweb plus
/// a defib-style double pulse ring.
class _ShatterPainter extends CustomPainter {
  final RoyalWeapon weapon;
  final Color accent;
  final List<_ImpactFx> impacts;
  final List<_ProjFx> projectiles;
  final int seed;

  const _ShatterPainter({
    required this.weapon,
    required this.accent,
    required this.impacts,
    required this.projectiles,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pre-pass: flash + vignette follow the freshest live impact.
    var flash = 0.0, dim = 0.0;
    Offset? focus;
    for (final i in impacts) {
      final hot = (1 - i.age / 0.30).clamp(0.0, 1.0) * i.fade;
      if (hot >= flash) {
        flash = hot;
        focus = i.at;
      }
      dim = math.max(dim, math.min(1.0, i.age * 2.5) * i.fade);
    }
    final rect = Offset.zero & size;
    if (dim > 0 && impacts.isNotEmpty) {
      // The pane "loses light" around the damage: a soft radial darkening
      // anchored on the first blow.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              (impacts.first.at.dx / size.width) * 2 - 1,
              (impacts.first.at.dy / size.height) * 2 - 1,
            ),
            radius: 1.25,
            colors: [
              Colors.black.withValues(alpha: 0.05 * dim),
              Colors.black.withValues(alpha: 0.30 * dim),
            ],
          ).createShader(rect),
      );
    }
    if (flash > 0 && focus != null) {
      canvas.drawRect(rect,
          Paint()..color = Colors.white.withValues(alpha: 0.20 * flash));
    }

    for (final imp in impacts) {
      final rng = math.Random(seed + imp.index * 977);
      final alpha = math.min(1.0, imp.age * 2.5) * imp.fade;
      switch (weapon) {
        case RoyalWeapon.sword:
          _gash(canvas, imp.at, imp.dir, size.shortestSide * 0.42, alpha, rng);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 7, speed: 75);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.knightSword:
          _gash(canvas, imp.at, imp.dir, size.shortestSide * 0.60, alpha, rng,
              splinters: 9);
          // Sparks skitter along the fresh cut.
          final dirV = Offset(math.cos(imp.dir), math.sin(imp.dir));
          for (var i = 0; i < 7; i++) {
            final d = (rng.nextDouble() * 2 - 1) * size.shortestSide * 0.5;
            final drift = imp.age * (14 + rng.nextDouble() * 22);
            final p = imp.at +
                dirV * d +
                Offset(rng.nextDouble() * 8 - 4, -drift);
            canvas.drawCircle(
                p,
                1.6 + rng.nextDouble() * 1.6,
                Paint()
                  ..color = accent.withValues(
                      alpha: (1 - imp.age) * 0.8 * imp.fade));
          }
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 6, speed: 65);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.warClub:
          if (imp.index == 0) {
            // The crater: a full spiderweb that keeps propagating outward
            // for a beat after the hit — cracks that GROW read as weight.
            final grow = 0.55 +
                0.45 * Curves.easeOut.transform(math.min(1.0, imp.age * 1.4));
            _web(canvas, imp.at, alpha, rng,
                radius: size.shortestSide * 0.36,
                radials: 13,
                rings: 3,
                grow: grow);
            _shards(canvas, imp.at, imp.age, imp.fade, rng,
                count: 12, speed: 115);
          } else {
            // Aftershock: a second pulse rolls out of the same crater.
            _flashRing(canvas, size, imp.at, imp.age, imp.fade, span: 0.5);
            _shards(canvas, imp.at, imp.age, imp.fade, rng,
                count: 5, speed: 60);
          }
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.bow:
          _web(canvas, imp.at, alpha, rng,
              radius: size.shortestSide * 0.09, radials: 7, rings: 1);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 4, speed: 40);
          // The arrow stays embedded — tip buried at the impact, shaft
          // trailing back along its flight path, quivering as it settles.
          final wobble = math.sin(imp.age * 26) * (1 - imp.age) * 0.22;
          _arrow(canvas, imp.at, imp.dir, imp.fade, wobble: wobble);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade, span: 0.4);
        case RoyalWeapon.orbs:
          _burst(canvas, size, imp, alpha, rng);
        case RoyalWeapon.medKit:
          _web(canvas, imp.at, alpha, rng,
              radius: size.shortestSide * 0.18, radials: 9, rings: 2);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 7, speed: 80);
          // Defib double-pulse: two accent rings chasing each other out.
          for (var k = 0; k < 2; k++) {
            final p = (imp.age * 1.3 - k * 0.22).clamp(0.0, 1.0);
            if (p <= 0 || p >= 1) continue;
            canvas.drawCircle(
                imp.at,
                size.shortestSide * (0.05 + 0.20 * p),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3 * (1 - p) + 1
                  ..color =
                      accent.withValues(alpha: (1 - p) * 0.55 * imp.fade));
          }
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.spear:
          // A PUNCTURE: a tight hole with long splits running out of it. Not
          // the club's wide crater — all of the force went through one point.
          _web(canvas, imp.at, alpha, rng,
              radius: size.shortestSide * 0.15, radials: 9, rings: 2);
          _gash(canvas, imp.at, imp.dir, size.shortestSide * 0.34, alpha, rng,
              splinters: 6);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 6, speed: 105);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.daggers:
          // Short, shallow, and fast — three of these land in half a second,
          // so each one has to stay small or the glass reads as pulverised.
          _gash(canvas, imp.at, imp.dir, size.shortestSide * 0.26, alpha, rng,
              splinters: 4);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 4, speed: 60);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade, span: 0.3);
      }
    }

    // Projectiles in flight, above the damage.
    for (final p in projectiles) {
      switch (p.kind) {
        case _ProjKind.arrow:
          // Speed ghosts trail the shaft.
          final v = Offset(math.cos(p.dir), math.sin(p.dir));
          for (var g = 1; g <= 2; g++) {
            _arrow(canvas, p.at - v * (10.0 * g), p.dir, 0.22 / g);
          }
          _arrow(canvas, p.at, p.dir, 1);
        case _ProjKind.orb:
          final v = Offset(math.cos(p.dir), math.sin(p.dir));
          for (var g = 1; g <= 3; g++) {
            canvas.drawCircle(
                p.at - v * (9.0 * g),
                7.0 - g * 1.6,
                Paint()..color = accent.withValues(alpha: 0.30 / g));
          }
          canvas.drawCircle(
              p.at,
              13,
              Paint()
                ..color = accent.withValues(alpha: 0.45)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          canvas.drawCircle(p.at, 7, Paint()..color = accent);
          canvas.drawCircle(p.at.translate(-2, -2), 2.6,
              Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
  }

  // ── Fracture primitives ──────────────────────────────────────────────────

  /// A jagged crack polyline wandering from [from] along [ang].
  Path _jag(Offset from, double ang, double len, math.Random rng,
      {int steps = 5, double wobble = 0.5}) {
    final path = Path()..moveTo(from.dx, from.dy);
    var p = from;
    var a = ang;
    final segLen = len / steps;
    for (var s = 0; s < steps; s++) {
      a += (rng.nextDouble() - 0.5) * wobble;
      p += Offset(math.cos(a), math.sin(a)) * segLen;
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// Three-layer crack stroke: accent under-glow, dark core, white glint —
  /// broken glass catches light on both lips of the fracture.
  void _strokeCrack(Canvas canvas, Path path, double alpha,
      {double core = 3.4}) {
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = core + 2.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..color = accent.withValues(alpha: 0.22 * alpha));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = core
          ..color = _ink.withValues(alpha: 0.60 * alpha));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = core * 0.36
          ..color = Colors.white.withValues(alpha: 0.55 * alpha));
  }

  /// The spiderweb: jagged radial cracks joined by jittered concentric rings.
  void _web(Canvas canvas, Offset at, double alpha, math.Random rng,
      {required double radius, int radials = 12, int rings = 3, double grow = 1}) {
    final angs = <double>[];
    final lens = <double>[];
    for (var i = 0; i < radials; i++) {
      final a = i / radials * 2 * math.pi + rng.nextDouble() * 0.5;
      final len = radius * (0.72 + rng.nextDouble() * 0.45) * grow;
      angs.add(a);
      lens.add(len);
      _strokeCrack(canvas, _jag(at, a, len, rng, steps: 4, wobble: 0.55),
          alpha, core: 3.0);
    }
    for (var r = 0; r < rings; r++) {
      final ring = Path();
      for (var i = 0; i <= radials; i++) {
        final k = i % radials;
        final rr = lens[k] * (0.28 + r * 0.27) *
            (1 + (rng.nextDouble() - 0.5) * 0.18);
        final p = at + Offset(math.cos(angs[k]), math.sin(angs[k])) * rr;
        if (i == 0) {
          ring.moveTo(p.dx, p.dy);
        } else {
          ring.lineTo(p.dx, p.dy);
        }
      }
      _strokeCrack(canvas, ring, alpha * 0.8, core: 2.0);
    }
  }

  /// A long ripped-through gash: two jagged halves out of the impact, short
  /// splinters branching off, and a parallel hairline glint (the lifted lip
  /// of the cut catching light).
  void _gash(Canvas canvas, Offset at, double ang, double halfLen,
      double alpha, math.Random rng,
      {int splinters = 6}) {
    _strokeCrack(canvas, _jag(at, ang, halfLen, rng, steps: 6, wobble: 0.26),
        alpha, core: 4.2);
    _strokeCrack(
        canvas,
        _jag(at, ang + math.pi, halfLen, rng, steps: 6, wobble: 0.26),
        alpha,
        core: 4.2);
    final dirV = Offset(math.cos(ang), math.sin(ang));
    for (var i = 0; i < splinters; i++) {
      final d = (rng.nextDouble() * 2 - 1) * halfLen * 0.8;
      final root = at + dirV * d;
      final branchA =
          ang + (rng.nextBool() ? 1 : -1) * (0.7 + rng.nextDouble() * 0.6);
      _strokeCrack(
          canvas,
          _jag(root, branchA, 14 + rng.nextDouble() * 26, rng,
              steps: 3, wobble: 0.5),
          alpha * 0.8,
          core: 1.9);
    }
    final perp = Offset(-dirV.dy, dirV.dx) * 2.8;
    canvas.drawLine(
        at - dirV * halfLen + perp,
        at + dirV * halfLen + perp,
        Paint()
          ..strokeWidth = 1.1
          ..color = Colors.white.withValues(alpha: 0.28 * alpha));
  }

  /// Glass slivers thrown from the blow, tumbling under a touch of gravity.
  void _shards(Canvas canvas, Offset at, double age, double fade,
      math.Random rng,
      {int count = 9, double speed = 90}) {
    if (age <= 0 || age >= 1) return;
    final a1 = (1 - age) * fade;
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.50 * a1);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _ink.withValues(alpha: 0.45 * a1);
    for (var i = 0; i < count; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final v = speed * (0.5 + rng.nextDouble());
      final pos = at +
          Offset(math.cos(a), math.sin(a)) * v * age +
          Offset(0, 130 * age * age);
      final s = 3.0 + rng.nextDouble() * 5;
      final rot = a + age * 6;
      final path = Path()
        ..moveTo(pos.dx + math.cos(rot) * s, pos.dy + math.sin(rot) * s)
        ..lineTo(pos.dx + math.cos(rot + 2.3) * s * 0.7,
            pos.dy + math.sin(rot + 2.3) * s * 0.7)
        ..lineTo(pos.dx + math.cos(rot + 4.4) * s * 0.55,
            pos.dy + math.sin(rot + 4.4) * s * 0.55)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
  }

  /// The moment of contact: a hot core + one shockwave ring racing out.
  void _flashRing(Canvas canvas, Size size, Offset at, double age, double fade,
      {double span = 0.30}) {
    if (age >= span) return;
    final p = age / span;
    canvas.drawCircle(
        at,
        size.shortestSide * (0.02 + 0.17 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1 - p) + 1
          ..color = Colors.white.withValues(alpha: (1 - p) * 0.65 * fade));
    canvas.drawCircle(
        at,
        size.shortestSide * 0.045 * (1 - p),
        Paint()..color = Colors.white.withValues(alpha: (1 - p) * 0.8 * fade));
  }

  /// An orb detonation: scorch blot, shock rings, a modest web, rising embers.
  void _burst(Canvas canvas, Size size, _ImpactFx imp, double alpha,
      math.Random rng) {
    canvas.drawCircle(
        imp.at,
        30 + 14 * imp.age,
        Paint()
          ..color = _ink.withValues(alpha: 0.22 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    _web(canvas, imp.at, alpha, rng,
        radius: size.shortestSide * 0.13, radials: 9, rings: 1);
    for (final k in const [0.0, 0.28]) {
      final p = (imp.age * 1.15 - k).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
          imp.at,
          size.shortestSide * (0.04 + 0.22 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - p) + 1
            ..color = accent.withValues(alpha: (1 - p) * 0.6 * imp.fade));
    }
    for (var i = 0; i < 6; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final r = 10 + rng.nextDouble() * 26;
      final p = imp.at +
          Offset(math.cos(a) * r, math.sin(a) * r * 0.5 - imp.age * 46);
      canvas.drawCircle(
          p,
          1.8 + rng.nextDouble() * 1.6,
          Paint()
            ..color =
                accent.withValues(alpha: (1 - imp.age) * 0.75 * imp.fade));
    }
    _flashRing(canvas, size, imp.at, imp.age, imp.fade);
  }

  /// A fletched arrow with its tip at [at], flying/embedded along [dir].
  void _arrow(Canvas canvas, Offset at, double dir, double alpha,
      {double wobble = 0}) {
    if (alpha <= 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(dir + wobble);
    // Shaft behind the tip (tip at the origin, pointing +x).
    canvas.drawLine(
        const Offset(-34, 0),
        const Offset(-3, 0),
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF6E4A2A).withValues(alpha: alpha));
    // Steel head.
    final head = Path()
      ..moveTo(2.5, 0)
      ..lineTo(-6, -3.4)
      ..lineTo(-6, 3.4)
      ..close();
    canvas.drawPath(
        head,
        Paint()..color = const Color(0xFFD7DCE4).withValues(alpha: alpha));
    // Fletching.
    final fl = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.9 * alpha);
    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
          const Offset(-34, 0), Offset(-39.5, 4.5 * s), fl);
      canvas.drawLine(
          const Offset(-29, 0), Offset(-34.5, 4.5 * s), fl);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShatterPainter old) =>
      old.impacts != impacts ||
      old.projectiles != projectiles ||
      old.seed != seed ||
      old.weapon != weapon;
}
