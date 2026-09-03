import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import 'royal_avatars.dart';
import 'royal_court_still.dart';
import 'royal_preview_stage.dart';

/// The court sheet's single media area: the character's moves and the app it
/// moves around in, as two swipeable pages instead of two stacked blocks.
///
/// **Why one area and not two.** The sheet had grown three separate pictures of
/// the same character — a 92dp circle, a 132dp animation reel and a 512dp
/// dashboard still — stacked down a sheet capped at half the screen height. On
/// a 914dp phone that was 1204dp of content in a 470dp window: the price and
/// the buy button were both below the fold, and a shopper had to scroll twice
/// to find out what anything cost. Product pages everywhere solve this the same
/// way — ONE media frame, several views, swipe between them — and the reason it
/// is worth copying is that it puts the decision (price, action) back on the
/// first screen without showing the reader any less.
///
/// The pages are the same height so the frame never resizes under a thumb
/// mid-swipe, and each page keeps the control that belongs to it: the still's
/// Without/With comparison rides on page two rather than becoming a second
/// global control.
class RoyalShowcase extends StatefulWidget {
  const RoyalShowcase({super.key, required this.royal});

  final RoyalAvatar royal;

  @override
  State<RoyalShowcase> createState() => _RoyalShowcaseState();
}

class _RoyalShowcaseState extends State<RoyalShowcase> {
  /// Height of the media frame. Set by the dashboard still, which is the taller
  /// page: it is a facsimile of a real screen, and shrinking it toward
  /// illegibility would defeat the point of showing it at all. The reel is
  /// drawn up to match rather than the still being cut down to fit.
  static const double _frameHeight = 288;

  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i == _page) return;
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onLight = Theme.of(context).brightness == Brightness.light;
    final accent =
        onLight ? widget.royal.theme.accentDeep : widget.royal.theme.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _frameHeight,
          child: PageView(
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              // Page one — what the character does.
              RoyalPreviewStage(
                royal: widget.royal,
                height: _frameHeight,
                // The reel has a whole page now rather than a strip between
                // two paragraphs, so the figure grows into it. Left at 1 it
                // was a thumbnail adrift in a frame three times its size.
                scale: 1.9,
              ),
              // Page two — and the app it does it in.
              RoyalCourtStillFrame(
                royal: widget.royal,
                dressed: _dressed,
                maxHeight: _frameHeight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // One slot under the frame, fixed height so nothing jumps on a swipe:
        // the reel explains itself in a line, the still hands over its A/B.
        // Sized for the SWITCHER, which is the taller of the two — at the
        // caption's height it cropped the labels off mid-letter.
        SizedBox(
          height: 40,
          child: Center(
            child: _page == 0
                ? Text(
                    context.l10n.royalPreviewCaption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      color: colors.textTertiary,
                    ),
                  )
                : _switcher(colors, accent),
          ),
        ),
        const SizedBox(height: 6),
        _dots(colors, accent),
      ],
    );
  }

  /// Which side of the still's A/B is showing. Lives here rather than in the
  /// frame so the choice survives swiping away to the reel and back.
  bool _dressed = true;

  /// The Without / With comparison. Deliberately two labelled halves rather
  /// than a toggle: "off" here means *the app you already have*, which is half
  /// the comparison rather than an absence, and a switch cannot say that.
  Widget _switcher(AppColors colors, Color accent) {
    Widget half(String label, bool dressedSide) {
      final on = _dressed == dressedSide;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _dressed = dressedSide),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: on ? accent.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(11),
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

  /// Page dots — tappable as well as swipeable. A dot is a small target, but
  /// leaving it inert is worse: some readers will try it, and a swipe nobody
  /// knows about is a page nobody sees.
  Widget _dots(AppColors colors, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 2; i++)
          GestureDetector(
            onTap: () => _goTo(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // Padding rather than margin: it grows the tap target without
              // growing the dot.
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                height: 6,
                width: _page == i ? 18 : 6,
                decoration: BoxDecoration(
                  color: _page == i ? accent : colors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
