import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
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
/// The A/B switch is the point of the whole widget. One dressed still is a
/// pretty picture; the pair is the only way to see WHICH parts of the screen
/// the court actually touches.
class RoyalCourtStill extends StatefulWidget {
  const RoyalCourtStill({super.key, required this.royal});

  final RoyalAvatar royal;

  @override
  State<RoyalCourtStill> createState() => _RoyalCourtStillState();
}

class _RoyalCourtStillState extends State<RoyalCourtStill> {
  /// Which side of the A/B the user is looking at. Starts dressed: they opened
  /// a royal's sheet, so the royal is what they came to see.
  bool _dressed = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onLight = Theme.of(context).brightness == Brightness.light;
    final accent =
        onLight ? widget.royal.theme.accentDeep : widget.royal.theme.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _switcher(colors, accent),
        const SizedBox(height: 10),
        // The still is only redrawn, never re-laid-out, when the switch flips:
        // both sides are the same widget at the same size, so the eye can
        // compare them without hunting for what moved.
        RoyalCourtStillFrame(
          royal: widget.royal,
          dressed: _dressed,
        ),
        const SizedBox(height: 8),
        Text(
          _dressed
              ? context.l10n.royalStillDressedCaption(
                  context.l10n.royalAvatarName(widget.royal.id),
                )
              : context.l10n.royalStillPlainCaption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.3,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// A two-up segmented switch. Deliberately not a toggle: both states need a
  /// visible label, because "off" here means *the app you already have* and
  /// that is half the comparison rather than an absence.
  Widget _switcher(AppColors colors, Color accent) {
    Widget half(String label, bool dressedSide) {
      final on = _dressed == dressedSide;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _dressed = dressedSide),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: on ? accent.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: on ? accent.withValues(alpha: 0.55) : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: on ? accent : colors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          half(context.l10n.royalStillWithout, false),
          const SizedBox(width: 4),
          half(
            context.l10n.royalStillWith(
              context.l10n.royalAvatarName(widget.royal.id),
            ),
            true,
          ),
        ],
      ),
    );
  }
}

/// The still itself, with the royal's header circle and its bottom-lane
/// stroll. Split out from [RoyalCourtStill] so a render proof (or a test) can
/// pin one side of the A/B without driving the switch.
class RoyalCourtStillFrame extends StatefulWidget {
  const RoyalCourtStillFrame({
    super.key,
    required this.royal,
    required this.dressed,
  });

  final RoyalAvatar royal;

  /// False shows the app as it is today — same still, no court dress, no
  /// character. That side is not a lesser preview; it is the control.
  final bool dressed;

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

    return Stack(
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
