import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import '../services/app_icon_service.dart';
import '../widgets/brand_logo.dart';

/// A cold-start skin for the splash: ambient ground, accent, and brand mark.
/// The default is the gold-on-navy identity; when a royal launcher icon is
/// active the splash wears that gem's family instead, so (e.g.) the ruby mark
/// never sits on a clashing blue field.
class _SplashSkin {
  final List<Color> bg; // background gradient (top-left → bottom-right)
  final Color accent; // shimmer, motto, progress, ring — replaces the gold
  final Color glowTop; // ambient glow behind the badge (opacity baked in)
  final Color glowBottom; // second ambient glow (opacity baked in)
  final String logoAsset; // the brand mark artwork

  const _SplashSkin({
    required this.bg,
    required this.accent,
    required this.glowTop,
    required this.glowBottom,
    required this.logoAsset,
  });
}

String _royalLogo(String v) => 'assets/branding/royal/$v.png';

/// The classic identity — kept pixel-identical to the pre-royal splash.
final _SplashSkin _defaultSkin = _SplashSkin(
  bg: const [Color(0xFF23273A), Color(0xFF0E1018)],
  accent: AppColors.gold,
  glowTop: AppColors.gold.withValues(alpha: 0.12),
  glowBottom: const Color(0xFF3A4163).withValues(alpha: 0.20),
  logoAsset: kBrandLogoAsset,
);

/// Per-gem splash skins, keyed by the RoyalAppIcon variant name. Each ground
/// is a deep, desaturated tint of the gem so the glowing mark reads clearly;
/// the accent is the gem's vivid signature (replacing the gold).
final Map<String, _SplashSkin> _gemSkins = {
  'ruby': _SplashSkin(
    bg: const [Color(0xFF2A0B12), Color(0xFF0C0304)],
    accent: const Color(0xFFFF4658),
    glowTop: const Color(0xFFFF4658).withValues(alpha: 0.16),
    glowBottom: const Color(0xFF7A1020).withValues(alpha: 0.22),
    logoAsset: _royalLogo('ruby'),
  ),
  'amethyst': _SplashSkin(
    bg: const [Color(0xFF1E0E2E), Color(0xFF0A0516)],
    accent: const Color(0xFFC08CFF),
    glowTop: const Color(0xFFC08CFF).withValues(alpha: 0.16),
    glowBottom: const Color(0xFF4A2A7A).withValues(alpha: 0.24),
    logoAsset: _royalLogo('amethyst'),
  ),
  'emerald': _SplashSkin(
    bg: const [Color(0xFF0A2A1E), Color(0xFF03110B)],
    accent: const Color(0xFF34E0A8),
    glowTop: const Color(0xFF34E0A8).withValues(alpha: 0.14),
    glowBottom: const Color(0xFF0E5A40).withValues(alpha: 0.24),
    logoAsset: _royalLogo('emerald'),
  ),
  'golden': _SplashSkin(
    bg: const [Color(0xFF2A2410), Color(0xFF0E0B02)],
    accent: const Color(0xFFFFC93C),
    glowTop: const Color(0xFFFFC93C).withValues(alpha: 0.14),
    glowBottom: const Color(0xFF5A4A10).withValues(alpha: 0.22),
    logoAsset: _royalLogo('golden'),
  ),
  'bronze': _SplashSkin(
    bg: const [Color(0xFF2A1A0E), Color(0xFF0E0803)],
    accent: const Color(0xFFE0A96B),
    glowTop: const Color(0xFFE0A96B).withValues(alpha: 0.15),
    glowBottom: const Color(0xFF6A4522).withValues(alpha: 0.22),
    logoAsset: _royalLogo('bronze'),
  ),
  'silver': _SplashSkin(
    bg: const [Color(0xFF1B1F27), Color(0xFF080A0E)],
    accent: const Color(0xFFCBD5E1),
    glowTop: const Color(0xFFCBD5E1).withValues(alpha: 0.12),
    glowBottom: const Color(0xFF3A4150).withValues(alpha: 0.20),
    logoAsset: _royalLogo('silver'),
  ),
};

_SplashSkin _skinFor(String? variant) => _gemSkins[variant] ?? _defaultSkin;

/// Premium animated splash. The brand mark scales/fades in with a rotating
/// shimmer ring, the wordmark and motto rise beneath it, and a thin progress
/// line fills before [onComplete] fires. When a royal launcher icon is active
/// the whole splash wears that gem's skin (see [_skinFor]).
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

  // The gem skin matching the active launcher icon, resolved once from the
  // value warmed in main() — so the first frame is already correct (no flash).
  final _SplashSkin _skin = _skinFor(AppIconService.activeVariant);

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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _skin.bg,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Soft ambient glow behind the badge
            Positioned(top: -90, right: -70, child: _glow(220, _skin.glowTop)),
            Positioned(
              bottom: -110,
              left: -80,
              child: _glow(260, _skin.glowBottom),
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
                              const SizedBox(height: 8),
                              // The brand motto, as two calm letterspaced
                              // lines under the wordmark.
                              Text(
                                'THE PRIVATE, OFFLINE BUDGET TRACKER',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w600,
                                  color: _skin.accent.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'THAT DOES THE WORK FOR YOU',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.45),
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
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(_skin.accent),
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
                          _skin.accent.withValues(alpha: 0.0),
                          _skin.accent.withValues(alpha: 0.0),
                          _skin.accent.withValues(alpha: 0.9),
                          _skin.accent.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.55, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Inner disc carrying the brand mark — the active skin's artwork,
              // circle-cropped inside a thin accent ring.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _skin.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: BrandLogo(
                  size: 94,
                  circular: true,
                  assetPath: _skin.logoAsset,
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
