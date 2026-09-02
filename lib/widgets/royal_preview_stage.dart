import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import 'royal_avatars.dart';
import 'royal_character.dart';
import 'royal_reactions.dart';

/// A short looping reel of what a royal actually DOES once equipped.
///
/// The circle avatar beside it is the thing that lands on the profile, but it
/// is not the thing being sold: the ROYALTY tier is the full-body chibi that
/// strolls the app, rides in at launch and signs off with its own signature
/// move. Before this existed a buyer was asked to pay ₹49 for a description of
/// an animation they had never seen — so the reel runs on the LOCKED sheet
/// too, which is the only place it really matters.
///
/// The reel is deliberately three beats and about eight seconds: long enough
/// to read as a performance, short enough that the loop point never feels like
/// a stall while someone is deciding.
class RoyalPreviewStage extends StatefulWidget {
  const RoyalPreviewStage({
    super.key,
    required this.royal,
    this.height = 132,
  });

  final RoyalAvatar royal;

  /// Stage height. The figure is drawn at its own box size inside this, so a
  /// taller stage gives the character more air, never a bigger character.
  final double height;

  @override
  State<RoyalPreviewStage> createState() => _RoyalPreviewStageState();
}

/// One beat of the reel: what the royal is doing, how fast that action's own
/// animation cycles, and how long the beat is held.
///
/// [cycleMs] is separate from [holdMs] because the two mean different things —
/// a gallop is a ~700ms loop that may repeat four times across a beat, while
/// an idle breath is one 1400ms cycle. Folding them together is what makes a
/// previewed ride look like a horse wading through treacle.
class _Beat {
  const _Beat(this.action, {required this.cycleMs, required this.holdMs});

  final RoyalAction action;
  final int cycleMs;
  final int holdMs;
}

class _RoyalPreviewStageState extends State<RoyalPreviewStage>
    with SingleTickerProviderStateMixin {
  late List<_Beat> _reel = _reelFor(widget.royal);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs),
  );

  int get _totalMs => _reel.fold(0, (sum, b) => sum + b.holdMs);

  @override
  void initState() {
    super.initState();
    // Deferred: MediaQuery isn't readable in initState, and a viewer who has
    // asked the system for reduced motion gets the held signature pose instead
    // of a loop they did not consent to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) _c.repeat();
    });
  }

  @override
  void didUpdateWidget(RoyalPreviewStage old) {
    super.didUpdateWidget(old);
    if (old.royal.id != widget.royal.id) {
      _reel = _reelFor(widget.royal);
      _c.duration = Duration(milliseconds: _totalMs);
      if (_c.isAnimating) _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// idle → signature → travel. Three beats, because one move reads as a still
  /// image with a twitch and the whole point is to show range.
  static List<_Beat> _reelFor(RoyalAvatar r) {
    final signature = royalSignatureAction(r.id);
    return [
      const _Beat(RoyalAction.idle, cycleMs: 1400, holdMs: 2000),
      _Beat(signature, cycleMs: 1400, holdMs: 2800),
      _travelBeat(r),
    ];
  }

  /// How this royal gets about. Everyone rides something except the Huntress,
  /// whose crossing is a one-shot run/somersault/land SEQUENCE driven by the
  /// host's leg progress — fed a repeating cycle it restarts mid-tumble.
  ///
  /// She runs instead. The blade dance was the first choice and it was wrong:
  /// it is a planted, all-wrists move, so all three of her beats came out as
  /// the same standing pose holding the same knives, and a reel where nothing
  /// changes sells nothing. A run is unmistakably travel, and it is the honest
  /// answer for the one royal with no mount.
  static _Beat _travelBeat(RoyalAvatar r) => r.id == 'huntress'
      ? const _Beat(RoyalAction.run, cycleMs: 420, holdMs: 2800)
      : const _Beat(RoyalAction.ride, cycleMs: 700, holdMs: 2800);

  /// Which beat is running at reel position [ms], and how far into that beat's
  /// own animation cycle we are.
  (_Beat, double) _beatAt(double ms) {
    var acc = 0.0;
    for (final beat in _reel) {
      if (ms < acc + beat.holdMs) {
        return (beat, ((ms - acc) / beat.cycleMs) % 1);
      }
      acc += beat.holdMs;
    }
    // Past the end (only reachable on a rounding edge): hold the last beat.
    return (_reel.last, 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onLight = Theme.of(context).brightness == Brightness.light;
    final accent =
        onLight ? widget.royal.theme.accentDeep : widget.royal.theme.accent;

    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        // The court's own velvet, kept faint: this is a stage the character
        // stands on, not a second avatar backdrop competing with the circle.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: onLight ? 0.10 : 0.16),
            colors.cardAlt.withValues(alpha: onLight ? 0.7 : 0.35),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Stopped controller (reduced motion) parks on the signature, held
          // at the pose the contact sheets are judged on.
          final (beat, t) = _c.isAnimating
              ? _beatAt(_c.value * _totalMs)
              : (_reel[1], 0.45);
          final box = royalActionIsMounted(beat.action)
              ? kRoyalRideBox
              : kRoyalStandBox;
          return Center(
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: CustomPaint(
                painter: RoyalCharacterPainter(
                  royal: widget.royal,
                  action: beat.action,
                  t: t,
                  // Facing the reader: the signature moves are aimed at the
                  // user, and a preview that shows a royal's back is not a
                  // preview of anything.
                  facing: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
