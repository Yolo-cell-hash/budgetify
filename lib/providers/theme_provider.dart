import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app theme (light/dark mode)
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isInitialized => _isInitialized;

  /// Initialize theme from shared preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeKey);

    if (savedMode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedMode == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.light; // Default to light
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
    await _saveTheme();
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveTheme();
  }

  /// Save theme preference
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}

/// App theme definitions — "midnight ink & champagne gold" design system.
///
/// Light mode: warm porcelain background, white cards with hairline borders,
/// deep ink as the interactive color. Dark mode: rich near-black surfaces
/// with champagne-gold accents. Both share the same semantic palette via
/// [AppColors].
class AppTheme {
  // ==================== LIGHT THEME (Porcelain) ====================
  static ThemeData get lightTheme {
    const c = AppColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.inkPrimary,
        onPrimary: Colors.white,
        secondary: AppColors.gold,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.inkPrimary,
        error: AppColors.dangerLight,
      ),
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: c.background,
      textTheme: _textTheme(c.text, c.textSecondary),
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.inkPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.inkPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkPrimary,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.inkPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inkPrimary, width: 1.5),
        ),
        hintStyle: TextStyle(color: c.textTertiary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.inkPrimary,
        unselectedItemColor: Color(0xFFA0A2A8),
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.inkPrimary,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: AppColors.gold,
      ),
      dividerColor: c.border,
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: AppColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.inkPrimary,
        labelStyle: TextStyle(color: c.text),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ==================== DARK THEME (Midnight & Gold) ====================
  static ThemeData get darkTheme {
    const c = AppColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: Color(0xFF15110A),
        secondary: AppColors.gold,
        onSecondary: Color(0xFF15110A),
        surface: DarkModeColors.surface,
        onSurface: Color(0xFFF2F2EF),
        error: AppColors.dangerDark,
      ),
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: c.background,
      textTheme: _textTheme(c.text, c.textSecondary),
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF15110A),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.gold),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: Color(0xFF15110A),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        hintStyle: TextStyle(color: c.textTertiary),
        labelStyle: TextStyle(color: c.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: DarkModeColors.surface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Color(0xFF6E7178),
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.gold,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: AppColors.gold,
      ),
      dividerColor: c.border,
      iconTheme: IconThemeData(color: c.textSecondary),
      dialogTheme: const DialogThemeData(
        backgroundColor: DarkModeColors.cardLight,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: DarkModeColors.cardLight,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DarkModeColors.cardLight,
        contentTextStyle: TextStyle(color: c.text),
        actionTextColor: AppColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: AppColors.gold,
        labelStyle: TextStyle(color: c.text),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Modern fade-through page transition (subtle horizontal fade) instead
  /// of the default zoom.
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  /// Shared type scale: tighter tracking on display sizes for a more
  /// refined, editorial feel; relaxed tracking on labels.
  static TextTheme _textTheme(Color text, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        color: text,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: text,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: text,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(color: text, letterSpacing: -0.1),
      bodyMedium: TextStyle(color: text, letterSpacing: -0.1),
      bodySmall: TextStyle(color: secondary),
      labelLarge: TextStyle(
        color: text,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Semantic palette shared by both modes. Use `AppColors.of(context)` in
/// widgets so colors track the active theme automatically.
class AppColors {
  // Brand constants (mode-independent)
  static const gold = Color(0xFFC8A75E); // champagne gold accent
  static const goldDeep = Color(0xFFA8843C);
  static const inkPrimary = Color(0xFF1B1E28); // deep ink (light-mode accent)
  static const successLight = Color(0xFF178A5B);
  static const successDark = Color(0xFF4CC795);
  static const dangerLight = Color(0xFFC94A50);
  static const dangerDark = Color(0xFFE8888C);

  // Hero card gradient — the dark "luxury card" used in both modes
  static const heroGradient = [Color(0xFF23273A), Color(0xFF131520)];

  final Color background;
  final Color surface;
  final Color card;
  final Color cardAlt;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color success;
  final Color danger;

  const AppColors._({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.success,
    required this.danger,
  });

  static const light = AppColors._(
    background: Color(0xFFF6F6F3),
    surface: Colors.white,
    card: Colors.white,
    cardAlt: Color(0xFFFAFAF8),
    border: Color(0xFFE9E9E4),
    text: Color(0xFF1B1E28),
    textSecondary: Color(0xFF6E727C),
    textTertiary: Color(0xFFA0A2A8),
    accent: inkPrimary,
    success: successLight,
    danger: dangerLight,
  );

  static const dark = AppColors._(
    background: Color(0xFF0A0B0E),
    surface: Color(0xFF121318),
    card: Color(0xFF16181E),
    cardAlt: Color(0xFF1D2026),
    border: Color(0xFF262931),
    text: Color(0xFFF2F2EF),
    textSecondary: Color(0xFF9A9DA6),
    textTertiary: Color(0xFF6E7178),
    accent: gold,
    success: successDark,
    danger: dangerDark,
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// Premium "hero card" treatment that adapts to the active theme.
///
/// Dark mode keeps the signature midnight-ink gradient with champagne gold.
/// Light mode gets its own warm porcelain-and-champagne treatment with deep
/// ink text — so the marquee cards (month expenses, net worth, budget gauge,
/// Wrapped, the forecast) feel intentional and premium in *both* modes,
/// instead of looking like a stray dark element dropped on a light canvas.
///
/// Use [HeroStyle.of] in any card that was previously a hardcoded dark
/// gradient so it tracks the theme from one place.
class HeroStyle {
  final List<Color> gradientColors;
  final Color border;
  final List<BoxShadow> shadow;

  /// Primary text/icon colour on the card.
  final Color foreground;

  /// Secondary (de-emphasised) text colour.
  final Color mutedForeground;

  /// Gold accent for eyebrow labels, chevrons, sparkles.
  final Color accent;

  /// Fill + hairline for inset tiles laid on the hero surface.
  final Color innerFill;
  final Color innerBorder;

  /// Hairline divider colour.
  final Color divider;

  /// Whether the surface itself is dark (drives child widgets like the
  /// savings-rate bar that have their own on-dark styling).
  final bool onDark;

  const HeroStyle({
    required this.gradientColors,
    required this.border,
    required this.shadow,
    required this.foreground,
    required this.mutedForeground,
    required this.accent,
    required this.innerFill,
    required this.innerBorder,
    required this.divider,
    required this.onDark,
  });

  LinearGradient get gradient => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// A muted foreground at an arbitrary [alpha] (0..1) — for the faintest
  /// captions and rule lines.
  Color foregroundAlpha(double alpha) =>
      foreground.withValues(alpha: alpha);

  static HeroStyle of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? _dark : _light;
  }

  static final HeroStyle _dark = HeroStyle(
    gradientColors: AppColors.heroGradient,
    border: AppColors.gold.withValues(alpha: 0.35),
    shadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
    foreground: Colors.white,
    mutedForeground: Colors.white.withValues(alpha: 0.62),
    accent: AppColors.gold,
    innerFill: Colors.white.withValues(alpha: 0.06),
    innerBorder: Colors.white.withValues(alpha: 0.08),
    divider: Colors.white.withValues(alpha: 0.12),
    onDark: true,
  );

  static final HeroStyle _light = HeroStyle(
    // Ivory → warm champagne: clearly richer than the plain white cards
    // around it, so the hero reads as the premium centrepiece.
    gradientColors: const [Color(0xFFFFFBF2), Color(0xFFEFDFBE)],
    border: AppColors.gold.withValues(alpha: 0.55),
    shadow: [
      BoxShadow(
        color: const Color(0xFF9A7B33).withValues(alpha: 0.16),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
    foreground: AppColors.inkPrimary,
    mutedForeground: AppColors.inkPrimary.withValues(alpha: 0.62),
    accent: AppColors.goldDeep,
    innerFill: Colors.white.withValues(alpha: 0.55),
    innerBorder: AppColors.inkPrimary.withValues(alpha: 0.07),
    divider: AppColors.inkPrimary.withValues(alpha: 0.10),
    onDark: false,
  );
}

/// Dark mode color constants for easy access throughout the app
class DarkModeColors {
  static const background = Color(0xFF0A0B0E);
  static const surface = Color(0xFF121318);
  static const card = Color(0xFF16181E);
  static const cardLight = Color(0xFF1D2026);
  static const primary = AppColors.gold;
  static const divider = Color(0xFF262931);
  static const textSecondary = Color(0xFF9A9DA6);
}
