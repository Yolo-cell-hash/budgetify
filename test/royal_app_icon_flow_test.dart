// The "Match app icon to my royal" decision surface, and the parade pacing.
//
// Both of these shipped as things that could only be checked by hand. The icon
// feature's whole decision lived behind a `Platform.isAndroid` guard, so on a
// test host every method returned early and nothing was reachable; the pacing
// was a literal buried in a switch. RoyalAppIcon.plan and
// RoyalReactionHost.debugBootTiming are the seams that make each one a number.
import 'package:budget_tracker/services/app_icon_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_reactions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int seedOf(String id) =>
      kRoyalAvatars.firstWhere((r) => r.id == id).spriteIndex;

  group('RoyalAppIcon.plan', () {
    test('the two newest royals have their own icons', () {
      // The pairings test only ever listed the original six, so a royal added
      // later could ship mapped to nothing without failing anything.
      expect(RoyalAppIcon.forRoyal['sentinel'], 'sapphire');
      expect(RoyalAppIcon.forRoyal['huntress'], 'absinthe');
      expect(RoyalAppIcon.forRoyal.length, kRoyalAvatars.length);
    });

    test('equipping a royal while the icon is default asks for a change', () {
      final p = RoyalAppIcon.plan(
        seed: seedOf('huntress'),
        enabled: true,
        applied: null,
      );
      expect(p.target, 'absinthe');
      expect(p.changes, isTrue);
    });

    test('re-equipping the royal already applied changes nothing', () {
      final p = RoyalAppIcon.plan(
        seed: seedOf('sentinel'),
        enabled: true,
        applied: 'sapphire',
      );
      expect(p.changes, isFalse, reason: 'must not restart for a no-op');
    });

    // The bug this feature actually had: the switch only recorded the
    // preference, and the icon was reconciled from the equip flow alone. So
    // turning it OFF left the launcher on the royal indefinitely — re-picking
    // the same royal could not even fix it, since that is not a change.
    test('turning the feature off plans a return to the default icon', () {
      final p = RoyalAppIcon.plan(
        seed: seedOf('huntress'),
        enabled: false,
        applied: 'absinthe',
      );
      expect(p.target, isNull);
      expect(p.changes, isTrue,
          reason: 'switching off must be something to apply, not a no-op');
    });

    test('a non-royal avatar returns to the default icon', () {
      final p = RoyalAppIcon.plan(seed: 0, enabled: true, applied: 'ruby');
      expect(p.target, isNull);
      expect(p.changes, isTrue);
    });

    test('off and already default is genuinely nothing to do', () {
      final p =
          RoyalAppIcon.plan(seed: 0, enabled: false, applied: null);
      expect(p.changes, isFalse);
    });

    test('every royal plans a change from the default, and a distinct one',
        () {
      final targets = <String>{};
      for (final r in kRoyalAvatars) {
        final p = RoyalAppIcon.plan(
          seed: r.spriteIndex,
          enabled: true,
          applied: null,
        );
        expect(p.target, isNotNull, reason: '${r.id} maps to no icon');
        expect(p.changes, isTrue);
        expect(targets.add(p.target!), isTrue,
            reason: '${r.id} shares an icon with another royal');
      }
    });
  });

  group('welcome parade pacing', () {
    // The Huntress's signature is four separate beats (throw, sweep-kick,
    // catch, present) where every other royal's is one gesture. On the flat
    // timeline the whole move got 784ms — under 200ms a beat, which reads as
    // a flicker rather than as choreography.
    test('no royal signature is squeezed under 700ms', () {
      for (final r in kRoyalAvatars) {
        final t = RoyalReactionHost.debugBootTiming(r.id);
        expect(t.signatureMs, greaterThanOrEqualTo(700),
            reason: '${r.id} signature is ${t.signatureMs}ms — too fast to '
                'read');
      }
    });

    test('the Huntress gets the longest parade, because it has the most beats',
        () {
      final hers = RoyalReactionHost.debugBootTiming('huntress');
      for (final r in kRoyalAvatars.where((r) => r.id != 'huntress')) {
        final other = RoyalReactionHost.debugBootTiming(r.id);
        expect(hers.totalMs, greaterThan(other.totalMs));
        expect(hers.signatureMs, greaterThan(other.signatureMs));
      }
    });

    // These two used to assert absolute floors — a 3500ms signature and a
    // 2500ms crossing — chosen while the somersault was being RESTARTED seven
    // times a crossing and the only lever anyone had was "give her more room".
    // With the restart fixed that room read as sluggishness instead. Length is
    // not the property worth pinning; PACE is.
    test('every signature beat runs at the court beat, nobody slower', () {
      // How many separate moves each signature is made of. The Huntress
      // throws, sweep-kicks, catches and presents; everyone else has one
      // gesture, so their whole signature is a single beat.
      const beatCount = {'huntress': 4};
      // The ceiling is for MOVES. A held pose is not a move run slowly, it is
      // a different thing being measured, and the Sentinel's whole signature
      // is that he stops and refuses to perform — stillness needs longer than
      // a gesture or it reads as the animation having stalled rather than as
      // deliberate. He is the only royal who signs off by not moving.
      const heldPose = {'sentinel'};
      for (final r in kRoyalAvatars) {
        final t = RoyalReactionHost.debugBootTiming(r.id);
        final perBeat = t.signatureMs / (beatCount[r.id] ?? 1);
        expect(perBeat, greaterThanOrEqualTo(700),
            reason: '${r.id} signature is ${perBeat.round()}ms a beat — too '
                'fast to read');
        if (heldPose.contains(r.id)) continue;
        expect(perBeat, lessThanOrEqualTo(kParadeBeatMs * 1.35),
            reason: '${r.id} signature is ${perBeat.round()}ms a beat against '
                'a ${kParadeBeatMs}ms court beat — it will read as slow '
                'next to the rest of the court');
      }
    });

    test('the Huntress somersault takes one beat, like every other move', () {
      final hers = RoyalReactionHost.debugBootTiming('huntress');
      expect(hers.rotationMs, closeTo(kParadeBeatMs, kParadeBeatMs * 0.15),
          reason: 'one full rotation is ${hers.rotationMs}ms against a '
              '${kParadeBeatMs}ms beat');
    });

    test('an unknown royal still gets the shared default timing', () {
      final t = RoyalReactionHost.debugBootTiming('nobody');
      expect(t.totalMs, 5600);
      expect(t.signatureMs, greaterThan(0));
    });
  });
}
