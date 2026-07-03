import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// A one-off coach mark: dims the screen, punches a glowing hole around the
/// widget under [targetKey] and explains it in a small card. Dismissed by its
/// button or a tap anywhere. Use sparingly — e.g. pointing out the Rewards
/// avatar right after Gamified Budgets is switched on.
///
/// Resolves when the overlay has fully faded out. No-ops when the target
/// isn't currently laid out.
Future<void> showSpotlight(
  BuildContext context, {
  required GlobalKey targetKey,
  required String title,
  required String message,
  required String buttonLabel,
}) {
  final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.attached || !box.hasSize) return Future.value();
  final target = box.localToGlobal(Offset.zero) & box.size;

  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SpotlightOverlay(
      target: target,
      title: title,
      message: message,
      buttonLabel: buttonLabel,
      onDismissed: () {
        entry.remove();
        completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _SpotlightOverlay extends StatefulWidget {
  final Rect target;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onDismissed;

  const _SpotlightOverlay({
    required this.target,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onDismissed,
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
  bool _leaving = false;

  @override
  void dispose() {
    _fade.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _pulse.stop();
    await _fade.reverse();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final center = widget.target.center;
    final radius = (widget.target.longestSide / 2) + 12;
    // Card sits under the hole when the target is in the top half of the
    // screen (the usual case: the Rewards avatar in the home header).
    final below = center.dy < screen.height / 2;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => CustomPaint(
                    painter: _SpotlightPainter(
                      center: center,
                      radius: radius,
                      pulse: Curves.easeInOut.transform(_pulse.value),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: below ? widget.target.bottom + 22 : null,
                bottom: below ? null : (screen.height - widget.target.top) + 22,
                child: Align(
                  alignment: center.dx > screen.width / 2
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16181E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.35),
                        ),
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
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _dismiss,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.gold,
                              ),
                              child: Text(
                                widget.buttonLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrim with a punched-out circle plus a breathing gold ring hugging it.
class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double pulse; // 0→1 loop

  const _SpotlightPainter({
    required this.center,
    required this.radius,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(scrim, Paint()..color = Colors.black.withOpacity(0.72));

    final wave = pulse < 0.5 ? pulse * 2 : (1 - pulse) * 2; // 0→1→0 breath
    canvas.drawCircle(
      center,
      radius + 2 + 3 * wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.gold.withOpacity(0.55 + 0.35 * wave),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.center != center ||
      oldDelegate.radius != radius;
}
