import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import 'avatars.dart';
import 'royal_avatars.dart';
import 'royal_character.dart';
import 'royal_reactions.dart';
import 'theme_preview_sheet.dart';

/// "Here is your app with this royal in it" — the dashboard still from the
/// Appearance picker, dressed by the court and inhabited by the character.
///
/// **Why this exists.** [RoyalPreviewStage] answers *what does it do* — the
/// idle, the signature move, the ride. It cannot answer *what does my app look
/// like afterwards*, which is the question a buyer is actually asking, because
/// a chibi on a velvet rectangle is a figure with no ground. Equipping a royal
/// changes three things the reel never shows: the avatar circle in the Home
/// header, every gold slot in the theme (buttons, links, the nav bar, the hero
/// card's border and eyebrow), and the character's ambient cameos across
/// whatever page is open.
///
/// **Why it is not a mock-up.** The frame is [ThemeStill] — the same facsimile
/// the theme picker ships — handed the court's real [ThemeDress] from
/// [courtDressFor]. Every colour in it is computed by the function that will
/// dress the live app, not chosen here to look good: if a royal's accent is
/// illegible on ivory, it is illegible in this still too. The figure walking
/// the bottom is [RoyalCharacterPainter] at the [kRoyalStandBox] proportions
/// the real cameo host uses. The only invented things are the demo rupee
/// figures the still has always carried, which are there so the preview
/// composes on a fresh install with no data.
///
/// The Without/With comparison that goes with it lives in `RoyalShowcase`,
/// which owns the page this frame sits on — one dressed still is a pretty
/// picture, and the pair is the only way to see WHICH parts of the screen the
/// court actually touches.
/// The still itself, with the royal's header circle and its bottom-lane
/// stroll. Split out from [RoyalCourtStill] so a render proof (or a test) can
/// pin one side of the A/B without driving the switch.
class RoyalCourtStillFrame extends StatefulWidget {
  const RoyalCourtStillFrame({
    super.key,
    required this.royal,
    required this.dressed,
    this.maxHeight,
  });

  final RoyalAvatar royal;

  /// False shows the app as it is today — same still, no court dress, no
  /// character. That side is not a lesser preview; it is the control.
  final bool dressed;

  /// Ceiling for the still, when the host has a fixed frame to fill. The still
  /// is content-sized (~379dp at sheet width), so a host with less room scales
  /// it down PROPORTIONALLY rather than cropping it — a cropped dashboard
  /// stops being a picture of a screen, which is the only thing it is for.
  /// Null leaves it at natural size.
  final double? maxHeight;

  @override
  State<RoyalCourtStillFrame> createState() => _RoyalCourtStillFrameState();
}

class _RoyalCourtStillFrameState extends State<RoyalCourtStillFrame>
    with SingleTickerProviderStateMixin {
  /// One full crossing plus the pause at the far edge.
  static const int _strollMs = 6400;

  /// Where in the crossing the mid-way wave happens, and how long it holds.
  /// Taken from the real [RoyalCameo.stroll]: the character walks in, stops
  /// in the middle to wave at the user, then walks out.
  static const double _waveStart = 0.42;
  static const double _waveEnd = 0.62;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _strollMs),
  );

  @override
  void initState() {
    super.initState();
    // Deferred like the reel's: MediaQuery is unreadable in initState, and a
    // viewer who asked the system for reduced motion gets the still standing
    // still rather than a loop they did not consent to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// The dress this royal applies, or null on the control side.
  ThemeDress? get _dress => widget.dressed
      ? courtDressFor('pixel', '${widget.royal.spriteIndex}')
      : null;

  @override
  Widget build(BuildContext context) {
    // Preview the variant the user is ACTUALLY in. Showing a royal on the
    // dark theme to somebody reading in light answers a question they did not
    // ask; the court sheet's own mode row is how they see the other one.
    final variant = context.watch<ThemeProvider>().variant;

    final still = Stack(
      children: [
        ThemeStill(variant: variant, dress: _dress),
        // The header circle. Positioned rather than threaded through
        // ThemeStill because it belongs to the royal, not to the theme, and
        // ThemeStill is shared with the Appearance picker.
        if (widget.dressed)
          Positioned(
            top: 12,
            right: 12,
            child: AvatarView(
              kind: 'pixel',
              value: '${widget.royal.spriteIndex}',
              size: 30,
              ring: false,
              // A grid of tiles all bursting at once is noise; this one lives
              // inside a still that is already busy.
              spawnRoyals: false,
            ),
          ),
        if (widget.dressed)
          Positioned.fill(
            child: IgnorePointer(child: _stroll()),
          ),
      ],
    );

    final cap = widget.maxHeight;
    if (cap == null) return still;
    // Measure at the width we are given, then scale the whole still — chrome,
    // character and all — to the height allowed. FittedBox alone would letterbox
    // against the parent's own constraints; laying the still out at its natural
    // height first and scaling that is what keeps it filling the frame's width.
    return LayoutBuilder(
      builder: (ctx, box) => ClipRect(
        child: SizedBox(
          height: cap,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(width: box.maxWidth, child: still),
          ),
        ),
      ),
    );
  }

  /// The ambient cameo, mirrored: a walk along the bottom of the page with a
  /// wave in the middle of it. This is the one behaviour the reel cannot show,
  /// because it is defined by the page it happens on.
  Widget _stroll() {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Stopped controller (reduced motion): park mid-page, mid-wave — the
        // pose that says "this character stands on your screen".
        final t = _c.isAnimating ? _c.value : 0.5;
        final waving = t >= _waveStart && t <= _waveEnd;

        // Walk right across the frame, holding position through the wave so
        // the character does not moonwalk while its arm is up.
        final double walked;
        if (t < _waveStart) {
          walked = t;
        } else if (t <= _waveEnd) {
          walked = _waveStart;
        } else {
          walked =
              _waveStart + (t - _waveEnd) / (1 - _waveEnd) * (1 - _waveStart);
        }

        final action = waving ? RoyalAction.wave : RoyalAction.walk;
        // Each action reads its own cycle: a walk is a ~700ms step loop, a
        // wave one 1400ms arc. Driving both off the crossing's clock is what
        // makes a previewed stroll look like wading.
        final cycleMs = waving ? 1400 : 700;
        final actionT = (t * _strollMs / cycleMs) % 1;

        return LayoutBuilder(
          builder: (ctx, box) {
            // Scaled down: the still is a pocket-size app, so a full-size
            // character standing in it would be a giant in a dollhouse.
            const scale = 0.62;
            final w = kRoyalStandBox.width * scale;
            final h = kRoyalStandBox.height * scale;
            // Travel from just off the left edge to just off the right one.
            final x = -w + walked * (box.maxWidth + w * 2);
            // Stand on the nav strip rather than floating over it — the
            // bottom lane is where the real cameo walks.
            final y = box.maxHeight - h - 26;

            return Stack(
              children: [
                Positioned(
                  left: x,
                  top: y,
                  width: w,
                  height: h,
                  child: CustomPaint(
                    painter: RoyalCharacterPainter(
                      royal: widget.royal,
                      action: action,
                      t: actionT,
                      // Face the direction of travel while walking, and turn
                      // to the reader for the wave — the wave is addressed to
                      // them, and a character waving at the wall is a bug.
                      facing: 1,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
