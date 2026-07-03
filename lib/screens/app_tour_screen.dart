import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_logo.dart';

/// The one-time app tour shown on first launch (and replayable from
/// Settings → About): five swipeable pages walking through auto-tracking,
/// tagging, the money tools, the opt-in Settings power-ups and Gamified
/// Budgets. Fixed ink+gold styling in both themes, matching the splash and
/// the shareable cards.
class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  /// Fade-in fullscreen route, used by the first-launch trigger on Home and
  /// the Settings → About replay entry.
  static Route<void> route() => PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => const AppTourScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _TourPoint {
  final IconData icon;
  final String text;
  const _TourPoint(this.icon, this.text);
}

class _TourPage {
  final IconData icon;
  final String title;
  final String lead;
  final List<_TourPoint> points;
  const _TourPage({
    required this.icon,
    required this.title,
    required this.lead,
    required this.points,
  });
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_TourPage> _pages(AppStrings l10n) => [
        _TourPage(
          icon: Icons.mark_chat_read_outlined,
          title: l10n.tour1Title,
          lead: l10n.tour1Lead,
          points: [
            _TourPoint(Icons.sms_outlined, l10n.tour1PointAuto),
            _TourPoint(Icons.lock_outline, l10n.tour1PointPrivate),
            _TourPoint(Icons.add_circle_outline, l10n.tour1PointManual),
          ],
        ),
        _TourPage(
          icon: Icons.sell_outlined,
          title: l10n.tour2Title,
          lead: l10n.tour2Lead,
          points: [
            _TourPoint(Icons.touch_app_outlined, l10n.tour2PointTap),
            _TourPoint(Icons.emoji_emotions_outlined, l10n.tour2PointCustom),
            _TourPoint(
                Icons.filter_alt_outlined, l10n.tour2PointUnclassified),
          ],
        ),
        _TourPage(
          icon: Icons.pie_chart_outline_rounded,
          title: l10n.tour3Title,
          lead: l10n.tour3Lead,
          points: [
            _TourPoint(Icons.donut_small_outlined, l10n.tour3PointBudgets),
            _TourPoint(Icons.event_repeat_outlined, l10n.tour3PointRecurring),
            _TourPoint(Icons.savings_outlined, l10n.tour3PointGoals),
            _TourPoint(Icons.auto_awesome_outlined, l10n.tour3PointWrapped),
          ],
        ),
        _TourPage(
          icon: Icons.settings_suggest_outlined,
          title: l10n.tour4Title,
          lead: l10n.tour4Lead,
          points: [
            _TourPoint(Icons.insights_rounded, l10n.tour4PointInsights),
            _TourPoint(Icons.monitor_heart_outlined, l10n.tour4PointHealth),
            _TourPoint(Icons.fingerprint, l10n.tour4PointSecurity),
            _TourPoint(
                Icons.visibility_off_outlined, l10n.tour4PointPrivacy),
            _TourPoint(Icons.palette_outlined, l10n.tour4PointThemes),
          ],
        ),
        _TourPage(
          icon: Icons.emoji_events_outlined,
          title: l10n.tour5Title,
          lead: l10n.tour5Lead,
          points: [
            _TourPoint(Icons.military_tech_outlined, l10n.tour5PointBadges),
            _TourPoint(
                Icons.local_fire_department_outlined, l10n.tour5PointStreak),
            _TourPoint(Icons.account_circle_outlined, l10n.tour5PointAvatar),
          ],
        ),
      ];

  void _next(int pageCount) {
    if (_page >= pageCount - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = _pages(l10n);
    final last = _page == pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF23273A), Color(0xFF0E1018)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Brand row, with Skip until the last page.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                child: Row(
                  children: [
                    const BrandLogo(size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'BUDGETIFY',
                      style: TextStyle(
                        color: AppColors.gold.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: last ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed:
                            last ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.55),
                        ),
                        child: Text(l10n.tourSkip),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemCount: pages.length,
                  itemBuilder: (_, i) => _buildPage(pages[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.gold
                            : Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF14161F),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => _next(pages.length),
                    child: Text(
                      last ? l10n.tourStart : l10n.tourNext,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

  Widget _buildPage(_TourPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.gold.withOpacity(0.20),
                  AppColors.gold.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withOpacity(0.35)),
            ),
            child: Icon(page.icon, size: 42, color: AppColors.gold),
          ),
          const SizedBox(height: 22),
          Text(
            page.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.lead,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          for (final point in page.points) _pointRow(point),
        ],
      ),
    );
  }

  Widget _pointRow(_TourPoint point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(point.icon, size: 18, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              point.text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
