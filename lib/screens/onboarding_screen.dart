import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../providers/app_preferences.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/background_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/brand_logo.dart';
import 'main_shell.dart';

/// Onboarding screen for first-time users
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding({bool smsGranted = false}) async {
    setState(() => _isLoading = true);

    try {
      if (smsGranted) {
        // Auto-enable hourly background scanning
        await BackgroundService.saveScanSettings(enabled: true);

        // Set flag so HomeScreen triggers an initial scan on first load
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('needs_initial_scan', true);
      }

      // Mark onboarding complete
      if (mounted) {
        await context.read<AppPreferences>().completeOnboarding();

        // Navigate to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.genericError(e), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: isDark
                  ? Color(0xFF2E313A)
                  : Color(0xFFE9E9E4),
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).primaryColor,
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildLanguagePage(isDark),
                  _buildWelcomePage(isDark),
                  _buildPermissionsPage(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shared page shell: the action button is PINNED at the bottom (always
  /// on-screen, always tappable) while everything above it scrolls when it
  /// doesn't fit. Longer-script languages (हिन्दी, தமிழ், తెలుగు…) used to
  /// overflow these fixed columns on smaller phones and push the Continue
  /// button out of reach — a soft-lock right at the front door. The
  /// min-height + IntrinsicHeight pairing keeps the airy Spacer layout on
  /// tall screens and degrades to scrolling on short ones.
  Widget _pageShell({
    required List<Widget> content,
    required Widget footer,
    EdgeInsets padding = const EdgeInsets.fromLTRB(32, 16, 32, 24),
  }) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          footer,
        ],
      ),
    );
  }

  /// First step: pick the app language. The choice applies instantly (the
  /// rest of onboarding — and the guided tour after it — re-render in it),
  /// defaults to English, and can be changed later in Settings.
  Widget _buildLanguagePage(bool isDark) {
    final current = context.watch<LocaleProvider>().language;
    return _pageShell(
      content: [
        const Spacer(),
        Icon(
          Icons.translate_rounded,
          size: 72,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.chooseLanguageTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.chooseLanguageDesc,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF9A9DA6) : const Color(0xFF6E727C),
          ),
        ),
        const SizedBox(height: 28),
        for (final lang in AppLanguage.values) ...[
          _languageOption(lang, current == lang, isDark),
          const SizedBox(height: 10),
        ],
        const Spacer(),
      ],
      footer: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            context.l10n.commonContinue,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _languageOption(AppLanguage lang, bool selected, bool isDark) {
    final accent = Theme.of(context).primaryColor;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.read<LocaleProvider>().setLanguage(lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(isDark ? 0.16 : 0.10)
              : (isDark ? const Color(0xFF16181E) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent
                : (isDark ? const Color(0xFF2E313A) : const Color(0xFFE9E9E4)),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.nativeName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (lang != AppLanguage.english)
                    Text(
                      lang.englishName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF8A8D96)
                            : const Color(0xFF6E727C),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected
                  ? accent
                  : (isDark ? const Color(0xFF4E525C) : const Color(0xFFD5D5CF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    final hero = HeroStyle.of(context);
    final colors = AppColors.of(context);
    return _pageShell(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      content: [
        const Spacer(flex: 2),
        // The real Budgetify mark, on a soft branded halo — the first
        // impression, not a stock wallet glyph.
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                colors.brandAccent.withValues(alpha: 0.18),
                colors.brandAccent.withValues(alpha: 0.0),
              ]),
            ),
            child: BrandLogo(
              size: 104,
              circular: true,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          context.l10n.onboardWelcomeTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.onboardWelcomeDesc,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: colors.textSecondary,
          ),
        ),
        const Spacer(flex: 1),
        // Feature highlights, on the premium hero surface.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            gradient: hero.gradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hero.border),
            boxShadow: hero.shadow,
          ),
          child: Column(
            children: [
              _welcomeFeature(hero, Icons.auto_awesome_motion_rounded,
                  context.l10n.onboardFeatSmsTitle,
                  context.l10n.onboardFeatSmsDesc),
              _welcomeDivider(hero),
              _welcomeFeature(hero, Icons.insights_rounded,
                  context.l10n.onboardFeatInsightsTitle,
                  context.l10n.onboardFeatInsightsDesc),
              _welcomeDivider(hero),
              _welcomeFeature(hero, Icons.lock_rounded,
                  context.l10n.onboardFeatPrivacyTitle,
                  context.l10n.onboardFeatPrivacyDesc),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
      footer: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(context.l10n.getStarted,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _welcomeFeature(
      HeroStyle hero, IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hero.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: hero.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: hero.foreground)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        fontSize: 12.5, color: hero.mutedForeground)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeDivider(HeroStyle hero) =>
      Divider(height: 1, color: hero.divider);

  Widget _buildPermissionsPage(bool isDark) {
    return _pageShell(
      content: [
        const Spacer(),
        Icon(
          Icons.sms_outlined,
          size: 80,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 32),
        Text(
          context.l10n.smsPermissionTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.smsPermissionDesc,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181E) : Color(0xFFE9F6F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF178A5B)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.smsPrivacyNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF11744C),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
      // The grant button gets the flexible slot so long localized labels
      // wrap inside it instead of overflowing the row.
      footer: Row(
        children: [
          TextButton(
              onPressed: _previousPage, child: Text(context.l10n.back)),
          const SizedBox(width: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () async {
                      // Request SMS permission
                      final smsStatus = await Permission.sms.request();

                      // Also request notification permission for Android 13+
                      await Permission.notification.request();

                      // Continue even if denied - user can grant later
                      await _completeOnboarding(
                        smsGranted: smsStatus.isGranted,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(context.l10n.grantPermissionAndStart,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
    );
  }
}
