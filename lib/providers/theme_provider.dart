import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of selectable app themes. [light] and [dark] are always available;
/// [smokyIvory], [seashellMauve], [onyxAmber] and [royalIndigo] are unlocked as
/// streak rewards (see `models/streak_reward.dart`). [dark] and [onyxAmber] are
/// dark-brightness; the rest are light-brightness.
enum AppThemeVariant {
  light,
  dark,
  smokyIvory,
  seashellMauve,
  onyxAmber,
  royalIndigo,
  midnightIndigo,
}

/// Provider for managing the active app theme variant.
class ThemeProvider extends ChangeNotifier {
  static const String _variantKey = 'theme_variant';
  static const String _legacyModeKey = 'theme_mode'; // pre-1.8 light/dark only

  AppThemeVariant _variant = AppThemeVariant.light;
  bool _isInitialized = false;

  /// When set, may re-dress the active variant's ThemeData — how an
  /// equipped ROYALTY avatar (with its app-wide theme toggle on) replaces
  /// the theme's gold/accent slots with the court shade everywhere, while
  /// every canvas colour stays the theme's own. The dress decides per
  /// variant (returning the base unchanged to opt out), so it re-evaluates
  /// when the user switches themes: royals dress only their home primary
  /// theme, never the reward themes. Synced from the gamification profile
  /// at startup and on every avatar save.
  ThemeDress? _themeDress;

  AppThemeVariant get variant => _variant;
  bool get isInitialized => _isInitialized;
  ThemeDress? get themeDress => _themeDress;

  void setThemeDress(ThemeDress? dress) {
    // Skip no-op updates. The common case — no royal equipped — sets this to
    // null on top of null; notifying anyway would rebuild the whole app for
    // nothing, and doing so during the onboarding→home hand-off (where this is
    // now synced, after the first frame) only adds churn to that transition.
    if (identical(_themeDress, dress)) return;
    _themeDress = dress;
    notifyListeners();
  }

  /// The [ThemeData] for the active variant (carries its own brightness),
  /// dressed by the equipped royal when this is its home primary theme.
  ThemeData get activeTheme {
    final base = AppTheme.of(_variant);
    final dress = _themeDress;
    if (dress == null) return base;
    return dress(_variant, base);
  }

  /// Kept for callers that still think in light/dark terms.
  bool get isDarkMode => _variant == AppThemeVariant.dark;
  ThemeMode get themeMode =>
      _variant == AppThemeVariant.dark ? ThemeMode.dark : ThemeMode.light;

  /// Initialize from shared preferences, migrating the legacy light/dark key.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_variantKey);
    if (saved != null) {
      _variant = _parse(saved);
    } else {
      final legacy = prefs.getString(_legacyModeKey);
      _variant =
          legacy == 'dark' ? AppThemeVariant.dark : AppThemeVariant.light;
    }

    _isInitialized = true;
    notifyListeners();
  }

  static AppThemeVariant _parse(String name) =>
      AppThemeVariant.values.firstWhere(
        (v) => v.name == name,
        orElse: () => AppThemeVariant.light,
      );

  /// Switch to [variant] and persist it. Callers are responsible for only
  /// offering unlocked streak themes; base light/dark are always allowed.
  Future<void> setVariant(AppThemeVariant variant) async {
    if (_variant == variant) return;
    _variant = variant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_variantKey, variant.name);
  }

  /// Developer-mode preview: apply [variant] for this session WITHOUT writing
  /// the real [_variantKey], so the user's earned theme is never overwritten.
  /// The dev-mode overlay is persisted separately by [DevMode] (and re-applied
  /// here at startup), so a previewed theme survives a restart while dev mode
  /// stays on, yet is dropped — reverting to the real theme — when dev mode is
  /// turned off.
  void setSessionVariant(AppThemeVariant variant) {
    if (_variant == variant) return;
    _variant = variant;
    notifyListeners();
  }

  /// Drop any session-only preview and return to the persisted variant
  /// (used when developer mode is switched off without restarting).
  Future<void> restorePersistedVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_variantKey);
    final restored =
        saved != null ? _parse(saved) : AppThemeVariant.light;
    if (restored == _variant) return;
    _variant = restored;
    notifyListeners();
  }

  /// Toggle between light and dark (kept for the base appearance selector).
  Future<void> toggleTheme() async {
    await setVariant(
      _variant == AppThemeVariant.dark
          ? AppThemeVariant.light
          : AppThemeVariant.dark,
    );
  }

  /// Set a specific [ThemeMode] (maps to the light/dark variants).
  Future<void> setThemeMode(ThemeMode mode) async {
    await setVariant(
      mode == ThemeMode.dark ? AppThemeVariant.dark : AppThemeVariant.light,
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
      extensions: [
        AppPalette(colors: AppColors.light, hero: HeroStyle._light),
      ],
      // Legacy ThemeData.primaryColor does NOT follow colorScheme.primary —
      // unset, Flutter defaults it to near-black in dark themes (invisible
      // icons) and swatch-blue in light ones. Pin it to the variant accent.
      primaryColor: AppColors.inkPrimary,
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
      extensions: [
        AppPalette(colors: AppColors.dark, hero: HeroStyle._dark),
      ],
      // See lightTheme: pin the legacy primaryColor, else it defaults to
      // grey[900] and primaryColor-tinted icons vanish on the dark canvas.
      primaryColor: AppColors.gold,
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

  // ============ STREAK-REWARD THEMES (warm, light-brightness) ============
  // "Smoky Blue & Warm Ivory" and "Soft Seashell & Dusty Mauve". Both follow
  // the light theme's structure but with their own palette + accent.
  static ThemeData get smokyIvoryTheme => _lightVariantTheme(
        AppColors.smokyIvory,
        accent: AppColors.smokyIvory.accent,
        hero: HeroStyle._smokyIvory,
      );

  static ThemeData get seashellMauveTheme => _lightVariantTheme(
        AppColors.seashellMauve,
        accent: AppColors.seashellMauve.accent,
        hero: HeroStyle._seashellMauve,
      );

  // ====== DARK-BRIGHTNESS STREAK REWARD THEME: "Onyx & Amber" ======
  // Mirrors the base dark theme's structure (near-black canvas, elevated grey
  // cards) but swaps champagne gold for a vivid amber accent. Dark ink is the
  // on-accent colour so text reads on the bright yellow.
  static ThemeData get onyxAmberTheme => _darkVariantTheme(
        AppColors.onyxAmber,
        accent: AppColors.onyxAmber.accent,
        hero: HeroStyle._onyxAmber,
        onAccent: const Color(0xFF202427),
      );

  // ===== LIGHT-BRIGHTNESS STREAK REWARD THEME: "Royal Indigo" (30-day) =====
  // The pinnacle reward. A frosted-lavender canvas with crisp frost-white
  // cards, a deep-indigo interactive accent and navy ink — crowned by a rich
  // violet hero carrying an electric-cyan jewel accent and a concentric-ring
  // aura. Mirrors the light theme's structure, turned regal.
  static ThemeData get royalIndigoTheme => _lightVariantTheme(
        AppColors.royalIndigo,
        accent: AppColors.royalIndigo.accent,
        hero: HeroStyle._royalIndigo,
      );

  // ==== DARK-BRIGHTNESS STREAK REWARD THEME: "Midnight Indigo" (45-day) ====
  // Royal Indigo's nocturne. The same palette tuned for the dark: a deep
  // indigo-navy canvas with elevated navy cards, light cool ink, an electric-
  // cyan interactive accent (dark navy ink rides on top) and a rich violet hero
  // wearing the same concentric-ring aura.
  static ThemeData get midnightIndigoTheme => _darkVariantTheme(
        AppColors.midnightIndigo,
        accent: AppColors.midnightIndigo.accent,
        hero: HeroStyle._midnightIndigo,
        onAccent: const Color(0xFF0D1430),
      );

  /// The [ThemeData] for any [AppThemeVariant].
  static ThemeData of(AppThemeVariant v) => switch (v) {
        AppThemeVariant.light => lightTheme,
        AppThemeVariant.dark => darkTheme,
        AppThemeVariant.smokyIvory => smokyIvoryTheme,
        AppThemeVariant.seashellMauve => seashellMauveTheme,
        AppThemeVariant.onyxAmber => onyxAmberTheme,
        AppThemeVariant.royalIndigo => royalIndigoTheme,
        AppThemeVariant.midnightIndigo => midnightIndigoTheme,
      };

  /// Builds a light-brightness theme from a palette + a single [accent] colour
  /// (used everywhere the base light theme uses ink/gold). White is the
  /// on-accent colour for buttons, FAB, snackbars, etc.
  static ThemeData _lightVariantTheme(
    AppColors c, {
    required Color accent,
    required HeroStyle hero,
    Color onAccent = Colors.white,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: [AppPalette(colors: c, hero: hero)],
      primaryColor: accent,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        surface: c.surface,
        onSurface: c.text,
        error: c.danger,
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
          backgroundColor: accent,
          foregroundColor: onAccent,
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
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
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
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: c.textTertiary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: accent,
        unselectedItemColor: c.textTertiary,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: accent,
      ),
      dividerColor: c.border,
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: accent,
        contentTextStyle: TextStyle(color: onAccent),
        actionTextColor: onAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: accent,
        labelStyle: TextStyle(color: c.text),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Builds a dark-brightness theme from a palette + a single [accent] colour —
  /// the dark counterpart to [_lightVariantTheme], used for dark streak-reward
  /// variants. [onAccent] is painted on top of the accent (buttons, FAB,
  /// snackbar text); pass a dark ink for light accents like amber.
  static ThemeData _darkVariantTheme(
    AppColors c, {
    required Color accent,
    required HeroStyle hero,
    required Color onAccent,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [AppPalette(colors: c, hero: hero)],
      primaryColor: accent,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        surface: c.surface,
        onSurface: c.text,
        error: c.danger,
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
          backgroundColor: accent,
          foregroundColor: onAccent,
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
        style: TextButton.styleFrom(foregroundColor: accent),
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
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
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: c.textTertiary),
        labelStyle: TextStyle(color: c.textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: accent,
        unselectedItemColor: c.textTertiary,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: accent,
      ),
      dividerColor: c.border,
      iconTheme: IconThemeData(color: c.textSecondary),
      dialogTheme: DialogThemeData(
        backgroundColor: c.cardAlt,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.cardAlt,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.cardAlt,
        contentTextStyle: TextStyle(color: c.text),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: accent,
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

  /// Signature decorative accent for icons/labels/chart strokes on *normal*
  /// surfaces (gold in light/dark, each reward theme's own hue otherwise).
  /// [brandAccentDeep] is a deeper companion for gradients and solid fills
  /// that carry white text. Replaces the old hardcoded `AppColors.gold`.
  final Color brandAccent;
  final Color brandAccentDeep;

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
    required this.brandAccent,
    required this.brandAccentDeep,
    required this.success,
    required this.danger,
  });

  /// A palette with selected slots replaced — used by the app-wide royal
  /// dress, which swaps the gold/accent slots for the equipped royal's
  /// shade while leaving every canvas colour untouched.
  AppColors copyWith({
    Color? accent,
    Color? brandAccent,
    Color? brandAccentDeep,
  }) =>
      AppColors._(
        background: background,
        surface: surface,
        card: card,
        cardAlt: cardAlt,
        border: border,
        text: text,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
        accent: accent ?? this.accent,
        brandAccent: brandAccent ?? this.brandAccent,
        brandAccentDeep: brandAccentDeep ?? this.brandAccentDeep,
        success: success,
        danger: danger,
      );

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
    brandAccent: goldDeep,
    brandAccentDeep: Color(0xFF8A6B2E),
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
    brandAccent: gold,
    brandAccentDeep: goldDeep,
    success: successDark,
    danger: dangerDark,
  );

  // ── Streak-reward palettes (both light-brightness) ──────────────────────
  // "Smoky Blue & Warm Ivory": warm ivory canvas, smoky-blue interactive.
  static const smokyIvory = AppColors._(
    background: Color(0xFFEDDECB), // warm ivory
    surface: Color(0xFFF7EFE3),
    card: Color(0xFFFAF4EA),
    cardAlt: Color(0xFFF2E7D6),
    border: Color(0xFFDFCFB8),
    text: Color(0xFF2E333B), // deep slate (legible on ivory)
    textSecondary: Color(0xFF5E6470),
    textTertiary: Color(0xFF8C8472),
    accent: Color(0xFF70798A), // smoky blue
    brandAccent: Color(0xFF70798A),
    brandAccentDeep: Color(0xFF5C6675),
    success: successLight,
    danger: dangerLight,
  );

  // "Soft Seashell & Dusty Mauve": blush seashell canvas, dusty-mauve accent.
  static const seashellMauve = AppColors._(
    background: Color(0xFFD7C4BE), // soft seashell
    surface: Color(0xFFE7D9D4),
    card: Color(0xFFEDE1DD),
    cardAlt: Color(0xFFE0CFC9),
    border: Color(0xFFCBB6AF),
    text: Color(0xFF3A2C2A), // deep mauve-brown
    textSecondary: Color(0xFF6E5854),
    textTertiary: Color(0xFF9C857F),
    accent: Color(0xFF9E756F), // dusty mauve
    brandAccent: Color(0xFF9E756F),
    brandAccentDeep: Color(0xFF8A645E),
    success: successLight,
    danger: dangerLight,
  );

  // "Onyx & Amber" (dark-brightness): deep onyx canvas, elevated gunmetal-grey
  // cards, vivid amber accent. Mirrors the base dark theme's structure.
  static const onyxAmber = AppColors._(
    background: Color(0xFF202427), // onyx
    surface: Color(0xFF2B3138), // gunmetal grey
    card: Color(0xFF2B3138),
    cardAlt: Color(0xFF333A42),
    border: Color(0xFF3A424B),
    text: Color(0xFFF1F3F5),
    textSecondary: Color(0xFF9BA3AD),
    textTertiary: Color(0xFF6B747E),
    accent: Color(0xFFFF8C00), // vivid orange
    brandAccent: Color(0xFFFF8C00),
    brandAccentDeep: Color(0xFFE07B00),
    success: successDark,
    danger: dangerDark,
  );

  // "Royal Indigo" (light-brightness, 30-day pinnacle): a frosted-lavender
  // canvas, crisp frost-white cards, deep-indigo interactive accent and navy
  // ink. Electric cyan is reserved for the violet hero (see HeroStyle).
  static const royalIndigo = AppColors._(
    background: Color(0xFFE7EDF8), // frosted lavender
    surface: Color(0xFFF4F7FC),
    card: Color(0xFFFBFCFF), // crisp frost-white
    cardAlt: Color(0xFFEAEFF9),
    border: Color(0xFFD4DCEE),
    text: Color(0xFF122353), // deep navy ink
    textSecondary: Color(0xFF5A6488),
    textTertiary: Color(0xFF8C95D1), // muted periwinkle
    accent: Color(0xFF4530B3), // deep royal indigo
    brandAccent: Color(0xFF5751D6), // indigo violet, legible on the light canvas
    brandAccentDeep: Color(0xFF4530B3),
    success: successLight,
    danger: dangerLight,
  );

  // "Midnight Indigo" (dark-brightness, 45-day): the dark twin of Royal Indigo
  // — a deep indigo-navy canvas, elevated navy cards, cool near-white ink, and
  // an electric-cyan accent that pops on the dark. Same palette family.
  static const midnightIndigo = AppColors._(
    background: Color(0xFF0D1430), // deepest indigo-navy
    surface: Color(0xFF152245),
    card: Color(0xFF172A52), // elevated navy card
    cardAlt: Color(0xFF1F3261),
    border: Color(0xFF2A3E6E),
    text: Color(0xFFE7EDFB), // cool near-white
    textSecondary: Color(0xFF8C95D1), // periwinkle
    textTertiary: Color(0xFF5E689A),
    accent: Color(0xFF27C0F5), // electric cyan
    brandAccent: Color(0xFF27C0F5),
    brandAccentDeep: Color(0xFF1BA6E0),
    success: successDark,
    danger: dangerDark,
  );

  /// The palette backing a given [AppThemeVariant].
  static AppColors forVariant(AppThemeVariant v) => switch (v) {
        AppThemeVariant.light => light,
        AppThemeVariant.dark => dark,
        AppThemeVariant.smokyIvory => smokyIvory,
        AppThemeVariant.seashellMauve => seashellMauve,
        AppThemeVariant.onyxAmber => onyxAmber,
        AppThemeVariant.royalIndigo => royalIndigo,
        AppThemeVariant.midnightIndigo => midnightIndigo,
      };

  static AppColors of(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>();
    if (palette != null) return palette.colors;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// Bundles the active variant's [AppColors] + [HeroStyle] onto its [ThemeData],
/// so `AppColors.of` / `HeroStyle.of` resolve the correct palette per variant
/// (not just by brightness). Registered via `ThemeData.extensions`.
class AppPalette extends ThemeExtension<AppPalette> {
  final AppColors colors;
  final HeroStyle hero;

  const AppPalette({required this.colors, required this.hero});

  @override
  AppPalette copyWith({AppColors? colors, HeroStyle? hero}) =>
      AppPalette(colors: colors ?? this.colors, hero: hero ?? this.hero);

  // Themes are discrete, so a snap at the midpoint is fine (no colour tween).
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      (other is AppPalette && t >= 0.5) ? other : this;
}

/// A per-variant restyling hook for the whole theme. Given the active
/// variant and its base [ThemeData], returns the theme to use — the base
/// itself to leave the variant untouched. Used by ThemeProvider to let an
/// equipped ROYALTY avatar dress its home primary theme app-wide (accent
/// slots + hero) while reward themes stay their hand-tuned selves.
typedef ThemeDress = ThemeData Function(AppThemeVariant variant, ThemeData base);

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

  /// Semantic income/positive and expense/negative colours tuned for *this*
  /// hero surface, so green/red stay vivid on the coloured reward heroes
  /// instead of falling back to the palette's dull light-surface variants.
  final Color positive;
  final Color negative;

  /// Whether the surface itself is dark (drives child widgets like the
  /// savings-rate bar that have their own on-dark styling).
  final bool onDark;

  /// Whether to paint the premium concentric-ring "aura" behind the hero
  /// content — the Royal Indigo reward's signature flourish. Off by default so
  /// every other theme's hero is unaffected. See [HeroAura].
  final bool showAura;

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
    required this.positive,
    required this.negative,
    required this.onDark,
    this.showAura = false,
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
    final palette = Theme.of(context).extension<AppPalette>();
    if (palette != null) return palette.hero;
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
    positive: AppColors.successDark,
    negative: AppColors.dangerDark,
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
    positive: AppColors.successLight,
    negative: AppColors.dangerLight,
    innerFill: Colors.white.withValues(alpha: 0.55),
    innerBorder: AppColors.inkPrimary.withValues(alpha: 0.07),
    divider: AppColors.inkPrimary.withValues(alpha: 0.10),
    onDark: false,
  );

  // Smoky-blue hero on the warm-ivory theme — a saturated accent centrepiece
  // with white text, mirroring how the dark theme uses its midnight hero.
  static final HeroStyle _smokyIvory = HeroStyle(
    gradientColors: const [Color(0xFF8A93A4), Color(0xFF5C6675)],
    border: const Color(0xFF70798A).withValues(alpha: 0.5),
    shadow: [
      BoxShadow(
        color: const Color(0xFF3A4150).withValues(alpha: 0.22),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
    foreground: Colors.white,
    mutedForeground: Colors.white.withValues(alpha: 0.66),
    accent: const Color(0xFFEDDECB), // warm ivory accent on the blue
    positive: const Color(0xFF3FD79E),
    negative: const Color(0xFFFF6F78),
    innerFill: Colors.white.withValues(alpha: 0.10),
    innerBorder: Colors.white.withValues(alpha: 0.14),
    divider: Colors.white.withValues(alpha: 0.16),
    onDark: true,
  );

  // Dusty-mauve hero on the soft-seashell theme.
  static final HeroStyle _seashellMauve = HeroStyle(
    gradientColors: const [Color(0xFFB08983), Color(0xFF8A645E)],
    border: const Color(0xFF9E756F).withValues(alpha: 0.5),
    shadow: [
      BoxShadow(
        color: const Color(0xFF5A3F3B).withValues(alpha: 0.22),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
    foreground: Colors.white,
    mutedForeground: Colors.white.withValues(alpha: 0.66),
    accent: const Color(0xFFF0E2DD), // light seashell accent on the mauve
    positive: const Color(0xFF3FD79E),
    negative: const Color(0xFFFF6F78),
    innerFill: Colors.white.withValues(alpha: 0.10),
    innerBorder: Colors.white.withValues(alpha: 0.14),
    divider: Colors.white.withValues(alpha: 0.16),
    onDark: true,
  );

  // Amber-on-onyx hero: a subtly elevated charcoal gradient with the amber
  // accent and white text — echoing how the base dark theme uses its midnight
  // hero with gold.
  static final HeroStyle _onyxAmber = HeroStyle(
    gradientColors: const [Color(0xFF2E343C), Color(0xFF1E2226)],
    border: const Color(0xFFFF8C00).withValues(alpha: 0.35),
    shadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.30),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
    foreground: Colors.white,
    mutedForeground: Colors.white.withValues(alpha: 0.62),
    accent: const Color(0xFFFF8C00),
    positive: AppColors.successDark,
    negative: AppColors.dangerDark,
    innerFill: Colors.white.withValues(alpha: 0.06),
    innerBorder: Colors.white.withValues(alpha: 0.08),
    divider: Colors.white.withValues(alpha: 0.12),
    onDark: true,
  );

  // Royal-indigo hero: a deep violet gradient with white text, an electric-cyan
  // jewel accent and the premium ring aura — the 30-day reward's centrepiece.
  static final HeroStyle _royalIndigo = HeroStyle(
    gradientColors: const [Color(0xFF5C53D8), Color(0xFF3A2596)],
    border: const Color(0xFF27C0F5).withValues(alpha: 0.40),
    shadow: [
      BoxShadow(
        color: const Color(0xFF2A1C70).withValues(alpha: 0.32),
        blurRadius: 26,
        offset: const Offset(0, 14),
      ),
    ],
    foreground: Colors.white,
    mutedForeground: Colors.white.withValues(alpha: 0.66),
    accent: const Color(0xFF27C0F5), // electric-cyan jewel on the violet
    positive: const Color(0xFF3FD79E),
    negative: const Color(0xFFFF6F78),
    innerFill: Colors.white.withValues(alpha: 0.10),
    innerBorder: Colors.white.withValues(alpha: 0.16),
    divider: Colors.white.withValues(alpha: 0.18),
    onDark: true,
    showAura: true,
  );

  // Midnight-indigo hero: a rich violet gradient lifted off the dark navy
  // canvas, with an electric-cyan jewel accent and the ring aura — Royal
  // Indigo's nocturne.
  static final HeroStyle _midnightIndigo = HeroStyle(
    gradientColors: const [Color(0xFF4A3FC9), Color(0xFF241874)],
    border: const Color(0xFF27C0F5).withValues(alpha: 0.42),
    shadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.42),
        blurRadius: 26,
        offset: const Offset(0, 14),
      ),
    ],
    foreground: Colors.white,
    mutedForeground: Colors.white.withValues(alpha: 0.66),
    accent: const Color(0xFF27C0F5), // electric-cyan jewel
    positive: const Color(0xFF3FD79E),
    negative: const Color(0xFFFF6F78),
    innerFill: Colors.white.withValues(alpha: 0.08),
    innerBorder: Colors.white.withValues(alpha: 0.12),
    divider: Colors.white.withValues(alpha: 0.14),
    onDark: true,
    showAura: true,
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
