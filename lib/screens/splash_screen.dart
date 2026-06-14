import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// Premium animated splash. A gold monogram badge scales/fades in with a
/// rotating shimmer ring, the wordmark rises beneath it, and a thin gold
/// progress line fills before [onComplete] fires.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // badge + wordmark entrance
  late final AnimationController _shimmer; // continuous ring sweep
  bool _done = false;

  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeFade;
  late final Animation<double> _ringFade;
  late final Animation<double> _wordFade;
  late final Animation<double> _wordSlide;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _badgeScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
    );
    _badgeFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _ringFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
    );
    _wordFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
    _wordSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _progress = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
    );

    _intro.forward().whenComplete(() {
      if (_done || !mounted) return;
      _done = true;
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF23273A), Color(0xFF0E1018)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Soft ambient gold glow behind the badge
            Positioned(
              top: -90,
              right: -70,
              child: _glow(220, AppColors.gold.withOpacity(0.12)),
            ),
            Positioned(
              bottom: -110,
              left: -80,
              child: _glow(260, const Color(0xFF3A4163).withOpacity(0.20)),
            ),
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _shimmer]),
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBadge(),
                      const SizedBox(height: 30),
                      Opacity(
                        opacity: _wordFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _wordSlide.value),
                          child: Column(
                            children: [
                              const Text(
                                'Budgetify',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'YOUR MONEY, BEAUTIFULLY TRACKED',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gold.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Bottom progress line
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: Center(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 3,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.gold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Opacity(
      opacity: _badgeFade.value,
      child: Transform.scale(
        scale: 0.7 + 0.3 * _badgeScale.value,
        child: SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating shimmer ring
              Opacity(
                opacity: _ringFade.value,
                child: Transform.rotate(
                  angle: _shimmer.value * 2 * math.pi,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          AppColors.gold.withOpacity(0.0),
                          AppColors.gold.withOpacity(0.0),
                          AppColors.gold.withOpacity(0.9),
                          AppColors.gold.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.55, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Inner ink disc
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14161F),
                  border: Border.all(color: AppColors.gold.withOpacity(0.35)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.gold,
                    size: 42,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 40)],
      ),
    );
  }
}
