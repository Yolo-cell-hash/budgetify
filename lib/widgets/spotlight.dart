import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// Hole shape punched around a spotlight target: [circle] suits small square
/// targets (the Rewards avatar, a nav icon); [rrect] suits rows and cards.
enum SpotlightShape { circle, rrect }

/// Handle to a live [showSpotlightTip] overlay, so tutorial flows can close
/// it programmatically once the awaited action happens.
class SpotlightHandle {
  SpotlightHandle._(this._entry, this._stateKey, this._onClosed);

  final OverlayEntry _entry;
  final GlobalKey<_SpotlightOverlayState> _stateKey;
  final VoidCallback? _onClosed;
  bool _closed = false;

  bool get isShowing => !_closed;

  /// Fade out and remove the overlay. Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _stateKey.currentState?._fadeOut();
    if (_entry.mounted) _entry.remove();
    _onClosed?.call();
  }
}

/// A one-off modal coach mark: dims the screen, punches a glowing hole around
/// the widget under [targetKey] and explains it in a small card. Dismissed by
/// its button or a tap anywhere; resolves once fully gone. Used for single
/// callouts like the Rewards avatar right after Gamified Budgets is enabled.
///
/// No-ops when the target isn't currently laid out.
Future<void> showSpotlight(
  BuildContext context, {
  required GlobalKey targetKey,
  required String title,
  required String message,
  required String buttonLabel,
  SpotlightShape shape = SpotlightShape.circle,
}) {
  final completer = Completer<void>();
  final handle = _show(
    context,
    targetKey: targetKey,
    title: title,
    message: message,
    shape: shape,
    passthrough: false,
    dismissOnBarrierTap: true,
    buttonLabel: buttonLabel,
    onClosed: completer.complete,
  );
  if (handle == null) return Future.value();
  return completer.future;
}

/// A persistent tutorial tip. With [passthrough] the punched hole stays
/// tappable, so the user performs the real action the tip points at — the
/// overlay does NOT self-dismiss on outside taps; the tutorial closes it via
/// the returned handle when its step advances. Info tips instead pass a
/// [buttonLabel] (with [onButton]) to advance explicitly.
///
/// Returns null when the target isn't currently laid out.
SpotlightHandle? showSpotlightTip(
  BuildContext context, {
  required GlobalKey targetKey,
  required String title,
  required String message,
  SpotlightShape shape = SpotlightShape.rrect,
  bool passthrough = true,
  String? buttonLabel,
  VoidCallback? onButton,
  String? skipLabel,
  VoidCallback? onSkip,
}) {
  return _show(
    context,
    targetKey: targetKey,
    title: title,
    message: message,
    shape: shape,
    passthrough: passthrough,
    dismissOnBarrierTap: false,
    buttonLabel: buttonLabel,
    onButton: onButton,
    skipLabel: skipLabel,
    onSkip: onSkip,
  );
}

SpotlightHandle? _show(
  BuildContext context, {
  required GlobalKey targetKey,
  required String title,
  required String message,
  required SpotlightShape shape,
  required bool passthrough,
  required bool dismissOnBarrierTap,
  String? buttonLabel,
  VoidCallback? onButton,
  String? skipLabel,
  VoidCallback? onSkip,
  VoidCallback? onClosed,
}) {
  final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.attached || !box.hasSize) return null;
  final target = box.localToGlobal(Offset.zero) & box.size;

  final overlay = Overlay.of(context, rootOverlay: true);
  final stateKey = GlobalKey<_SpotlightOverlayState>();
  late final SpotlightHandle handle;
  final entry = OverlayEntry(
    builder: (_) => _SpotlightOverlay(
      key: stateKey,
      target: target,
      shape: shape,
      title: title,
      message: message,
      passthrough: passthrough,
      dismissOnBarrierTap: dismissOnBarrierTap,
      buttonLabel: buttonLabel,
      onButton: onButton,
      skipLabel: skipLabel,
      onSkip: onSkip,
      onRequestClose: () => handle.close(),
    ),
  );
  handle = SpotlightHandle._(entry, stateKey, onClosed);
  overlay.insert(entry);
  return handle;
}

class _SpotlightOverlay extends StatefulWidget {
  final Rect target;
  final SpotlightShape shape;
  final String title;
  final String message;
  final bool passthrough;
  final bool dismissOnBarrierTap;
  final String? buttonLabel;
  final VoidCallback? onButton;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final VoidCallback onRequestClose;

  const _SpotlightOverlay({
    super.key,
    required this.target,
    required this.shape,
    required this.title,
    required this.message,
    required this.passthrough,
    required this.dismissOnBarrierTap,
    required this.onRequestClose,
    this.buttonLabel,
    this.onButton,
    this.skipLabel,
    this.onSkip,
  });

  @override
  State<_SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<_SpotlightOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _fade.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Reverse the entrance fade (driven by [SpotlightHandle.close]).
  Future<void> _fadeOut() async {
    if (!mounted) return;
    _pulse.stop();
    await _fade.reverse();
  }

  /// The punched hole, slightly padded out from the target itself.
  Rect get _hole => widget.shape == SpotlightShape.circle
      ? Rect.fromCircle(
          center: widget.target.center,
          radius: widget.target.longestSide / 2 + 12,
        )
      : widget.target.inflate(8);

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final hole = _hole;
    final below = widget.target.center.dy < screen.height / 2;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Scrim + ring are visuals only; hit testing belongs to the
            // barriers below so the hole can stay tappable in passthrough
            // mode.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => CustomPaint(
                    painter: _SpotlightPainter(
                      hole: hole,
                      shape: widget.shape,
                      pulse: Curves.easeInOut.transform(_pulse.value),
                    ),
                  ),
                ),
              ),
            ),
            ..._barriers(hole, screen),
            _card(screen, below),
          ],
        ),
      ),
    );
  }

  /// In passthrough mode: four absorbing rectangles around the hole leave the
  /// target itself tappable. Otherwise a single full-screen barrier (which
  /// also dismisses, for the modal variant).
  List<Widget> _barriers(Rect hole, Size screen) {
    Widget barrier() => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.dismissOnBarrierTap ? widget.onRequestClose : () {},
          child: const SizedBox.expand(),
        );

    if (!widget.passthrough) {
      return [Positioned.fill(child: barrier())];
    }

    final top = hole.top.clamp(0.0, screen.height);
    final bottom = hole.bottom.clamp(0.0, screen.height);
    final left = hole.left.clamp(0.0, screen.width);
    final right = hole.right.clamp(0.0, screen.width);
    return [
      Positioned(left: 0, top: 0, right: 0, height: top, child: barrier()),
      Positioned(left: 0, top: bottom, right: 0, bottom: 0, child: barrier()),
      Positioned(
          left: 0,
          top: top,
          width: left,
          height: bottom - top,
          child: barrier()),
      Positioned(
          left: right,
          top: top,
          right: 0,
          height: bottom - top,
          child: barrier()),
    ];
  }

  Widget _card(Size screen, bool below) {
    final hole = _hole;
    final hasActions = widget.buttonLabel != null || widget.skipLabel != null;
    return Positioned(
      left: 20,
      right: 20,
      top: below ? hole.bottom + 18 : null,
      bottom: below ? null : (screen.height - hole.top) + 18,
      child: Align(
        alignment: widget.target.center.dx > screen.width / 2
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF16181E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (hasActions) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (widget.skipLabel != null)
                        TextButton(
                          onPressed: () {
                            widget.onSkip?.call();
                            widget.onRequestClose();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.5),
                          ),
                          child: Text(
                            widget.skipLabel!,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      const Spacer(),
                      if (widget.buttonLabel != null)
                        TextButton(
                          onPressed: () {
                            widget.onButton?.call();
                            widget.onRequestClose();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gold,
                          ),
                          child: Text(
                            widget.buttonLabel!,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ] else
                  const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrim with a punched-out hole (circle or rounded rect) plus a breathing
/// gold ring hugging it.
class _SpotlightPainter extends CustomPainter {
  final Rect hole;
  final SpotlightShape shape;
  final double pulse; // 0→1 loop

  const _SpotlightPainter({
    required this.hole,
    required this.shape,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (shape == SpotlightShape.circle) {
      scrim.addOval(hole);
    } else {
      scrim.addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));
    }
    canvas.drawPath(scrim, Paint()..color = Colors.black.withOpacity(0.72));

    final wave = pulse < 0.5 ? pulse * 2 : (1 - pulse) * 2; // 0→1→0 breath
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.gold.withOpacity(0.55 + 0.35 * wave);
    final ringRect = hole.inflate(2 + 3 * wave);
    if (shape == SpotlightShape.circle) {
      canvas.drawOval(ringRect, ring);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(ringRect, const Radius.circular(18)),
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.hole != hole ||
      oldDelegate.shape != shape;
}
