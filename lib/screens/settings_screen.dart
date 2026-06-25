import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../app_info.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/streak_reward.dart';
import '../providers/theme_provider.dart';
import '../providers/app_preferences.dart';
import '../providers/locale_provider.dart';
import '../services/app_events.dart';
import '../services/app_lock_service.dart';
import '../services/backup_service.dart';
import '../services/background_service.dart';
import '../services/export_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/export_options_sheet.dart';
import 'manage_tags_screen.dart';
import 'recurring_screen.dart';
import 'streak_rewards_screen.dart';

/// Settings screen with theme toggle and auto-scan configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ExportService _exportService = ExportService();
  final BackupService _backupService = BackupService();
  bool _autoScanEnabled = true;
  int _scanIntervalHours = BackgroundService.defaultIntervalHours;
  DateTime? _lastScanTime;
  bool _appLockEnabled = false;
  bool _loading = true;
  int _longestStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await BackgroundService.getScanSettings();
    final lastScan = await BackgroundService.getLastScanTime();
    final appLock = await AppLockService().isEnabled();
    final streak = await GamificationService().streakInfo();
    setState(() {
      _autoScanEnabled = settings['enabled'] as bool;
      _scanIntervalHours = settings['intervalHours'] as int;
      _lastScanTime = lastScan;
      _appLockEnabled = appLock;
      _longestStreak = streak.longest;
      _loading = false;
    });
  }

  Future<void> _toggleAppLock(bool enable) async {
    final lockService = AppLockService();
    if (enable) {
      // Read the localized message before the async gap below.
      final noLockMessage = context.l10nRead.noScreenLock;
      if (!await lockService.isDeviceSupported()) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: noLockMessage,
          color: const Color(0xFFD25A5F),
        );
        return;
      }
      // Prove the user can actually unlock before turning it on
      final ok = await lockService.authenticate();
      if (!ok) return;
    }
    await lockService.setEnabled(enable);
    setState(() => _appLockEnabled = enable);
  }

  Future<void> _saveSettings() async {
    await BackgroundService.saveScanSettings(
      enabled: _autoScanEnabled,
      intervalHours: _scanIntervalHours,
    );
    if (mounted) {
      showAppToast(
        context,
        message: _autoScanEnabled
            ? context.l10nRead.autoScanEnabledToast
            : context.l10nRead.autoScanDisabledToast,
        type: _autoScanEnabled ? AppToastType.success : AppToastType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.settingsTitle,
            icon: Icons.settings_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader(context.l10n.appearance, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.l10n.theme,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1B1E28),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                  child: Row(
                    children: [
                      for (final v in AppThemeVariant.values)
                        Expanded(child: _themeTile(v, themeProvider)),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF2E313A) : const Color(0xFFE9E9E4),
                ),
                ListTile(
                  leading: Icon(
                    Icons.translate_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(context.l10n.language),
                  subtitle: Text(
                    localeProvider.language.nativeName,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8A8D96) : const Color(0xFF6E727C),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? const Color(0xFF8A8D96) : const Color(0xFF9A9DA6),
                  ),
                  onTap: () => _showLanguageSheet(localeProvider),
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF2E313A) : const Color(0xFFE9E9E4),
                ),
                ListTile(
                  leading: Icon(
                    Icons.local_fire_department_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(context.l10n.streakRewards),
                  subtitle: Text(
                    context.l10n.themesUnlocked(
                      unlockedStreakRewards(_longestStreak).length,
                      kStreakRewards.length,
                    ),
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8A8D96) : const Color(0xFF6E727C),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? const Color(0xFF8A8D96) : const Color(0xFF9A9DA6),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StreakRewardsScreen(),
                      ),
                    );
                    _loadSettings(); // refresh unlock count on return
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Auto-Scan Section
          _buildSectionHeader(context.l10n.autoScanSection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.schedule,
                    color: _autoScanEnabled ? Color(0xFF2AA76F) : Color(0xFF8A8D96),
                  ),
                  title: Text(context.l10n.autoScanTitle),
                  subtitle: Text(
                    _autoScanEnabled
                        ? context.l10n.autoScanOnDesc
                        : context.l10n.autoScanOffDesc,
                    style: TextStyle(
                      color: isDark
                          ? Color(0xFF8A8D96)
                          : Color(0xFF6E727C),
                    ),
                  ),
                  value: _autoScanEnabled,
                  onChanged: _loading
                      ? null
                      : (value) async {
                          setState(() => _autoScanEnabled = value);
                          await _saveSettings();
                        },
                ),
                if (_autoScanEnabled) ...[
                  Divider(
                    height: 1,
                    color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Text(
                          context.l10n.scanFrequency,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Color(0xFF1B1E28),
                          ),
                        ),
                      ),
                      // Horizontally scrollable so the wider options
                      // (Every 24h) never overflow the card
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          children: BackgroundService.intervalOptions.map((h) {
                            final selected = _scanIntervalHours == h;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(h == 1
                                    ? context.l10n.hourly
                                    : context.l10n.everyHours(h)),
                                selected: selected,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? (isDark
                                            ? const Color(0xFF15110A)
                                            : Colors.white)
                                      : (isDark
                                            ? Color(0xFF9A9DA6)
                                            : Color(0xFF6E727C)),
                                ),
                                onSelected: (_) async {
                                  setState(() => _scanIntervalHours = h);
                                  await _saveSettings();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  if (_lastScanTime != null) ...[
                    Divider(
                      height: 1,
                      color: isDark
                          ? Color(0xFF2E313A)
                          : Color(0xFFE9E9E4),
                    ),
                    ListTile(
                      leading: Icon(Icons.history, color: Color(0xFF8A8D96)),
                      title: Text(context.l10n.lastScan),
                      subtitle: Text(
                        DateFormat(
                          'MMM d, yyyy • h:mm a',
                        ).format(_lastScanTime!),
                        style: TextStyle(
                          color: isDark
                              ? Color(0xFF8A8D96)
                              : Color(0xFF6E727C),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Security Section
          _buildSectionHeader(context.l10n.securitySection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.fingerprint,
                    color: _appLockEnabled
                        ? const Color(0xFFA8843C)
                        : const Color(0xFF8A8D96),
                  ),
                  title: Text(context.l10n.appLock),
                  subtitle: Text(
                    _appLockEnabled
                        ? context.l10n.appLockOnDesc
                        : context.l10n.appLockOffDesc,
                    style: TextStyle(
                      color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                    ),
                  ),
                  value: _appLockEnabled,
                  onChanged: _loading ? null : _toggleAppLock,
                ),
                Divider(
                  height: 1,
                  color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
                ),
                SwitchListTile(
                  secondary: Icon(
                    context.watch<AppPreferences>().privacyMode
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: context.watch<AppPreferences>().privacyMode
                        ? const Color(0xFFA8843C)
                        : const Color(0xFF8A8D96),
                  ),
                  title: Text(context.l10n.hideAmounts),
                  subtitle: Text(
                    context.l10n.hideAmountsDesc,
                    style: TextStyle(
                      color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                    ),
                  ),
                  value: context.watch<AppPreferences>().privacyMode,
                  onChanged: (v) =>
                      context.read<AppPreferences>().setPrivacyMode(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Intelligence Section
          _buildSectionHeader(context.l10n.intelligenceSection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                Icons.insights_rounded,
                color: context.watch<AppPreferences>().aiPredictionMode
                    ? const Color(0xFFA8843C)
                    : const Color(0xFF8A8D96),
              ),
              title: Text(context.l10n.aiPredictionMode),
              subtitle: Text(
                context.l10n.aiPredictionModeDesc,
                style: TextStyle(
                  color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                ),
              ),
              value: context.watch<AppPreferences>().aiPredictionMode,
              onChanged: (v) =>
                  context.read<AppPreferences>().setAiPredictionMode(v),
            ),
          ),

          const SizedBox(height: 12),
          _buildSettingsCard(
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                Icons.monitor_heart_outlined,
                color: context.watch<AppPreferences>().financialHealthDetailed
                    ? const Color(0xFFA8843C)
                    : const Color(0xFF8A8D96),
              ),
              title: Text(context.l10n.detailedFinancialHealth),
              subtitle: Text(
                context.l10n.detailedFinancialHealthDesc,
                style: TextStyle(
                  color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                ),
              ),
              value: context.watch<AppPreferences>().financialHealthDetailed,
              onChanged: (v) => context
                  .read<AppPreferences>()
                  .setFinancialHealthDetailed(v),
            ),
          ),

          const SizedBox(height: 12),
          _buildSettingsCard(
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                Icons.emoji_events_outlined,
                color: context.watch<AppPreferences>().gamifiedMode
                    ? const Color(0xFFA8843C)
                    : const Color(0xFF8A8D96),
              ),
              title: Text(context.l10n.gamifiedBudgets),
              subtitle: Text(
                context.l10n.gamifiedBudgetsDesc,
                style: TextStyle(
                  color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                ),
              ),
              value: context.watch<AppPreferences>().gamifiedMode,
              onChanged: (v) =>
                  context.read<AppPreferences>().setGamifiedMode(v),
            ),
          ),

          const SizedBox(height: 24),

          // Backup Section
          _buildSectionHeader(context.l10n.backupSection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.shield_moon_outlined,
                    color: Color(0xFFA8843C),
                  ),
                  title: Text(context.l10n.createBackup),
                  subtitle: Text(
                    context.l10n.createBackupDesc,
                    style: TextStyle(
                      color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _createBackup,
                ),
                Divider(
                  height: 1,
                  color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings_backup_restore,
                    color: Color(0xFF178A5B),
                  ),
                  title: Text(context.l10n.restoreBackup),
                  subtitle: Text(
                    context.l10n.restoreBackupDesc,
                    style: TextStyle(
                      color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _restoreBackup,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader(context.l10n.dataSection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.autorenew_rounded,
                      color: Color(0xFF4A6489)),
                  title: Text(context.l10n.recurringPaymentsTitle),
                  subtitle: Text(
                    context.l10n.recurringSubtitle,
                    style: TextStyle(
                      color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecurringScreen()),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
                ),
                ListTile(
                  leading: Icon(Icons.sell_outlined, color: Color(0xFFC68A2E)),
                  title: Text(context.l10n.manageTags),
                  subtitle: Text(
                    context.l10n.manageTagsDesc,
                    style: TextStyle(
                      color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageTagsScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Export Section
          _buildSectionHeader(context.l10n.exportSection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(Icons.ios_share, color: Color(0xFF4A6489)),
              title: Text(context.l10n.exportData),
              subtitle: Text(
                context.l10n.exportDataDesc,
                style: TextStyle(
                  color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openExportSheet,
            ),
          ),

          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader(context.l10n.privacySection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(
                Icons.shield_outlined,
                color: Color(0xFF178A5B),
              ),
              title: Text(context.l10n.dataPrivateTitle),
              subtitle: Text(
                context.l10n.dataPrivateDesc,
                style: TextStyle(
                  color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context.l10n.aboutSection, isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Budgetify'),
              subtitle: Text(context.l10n.versionLabel(kAppVersion)),
            ),
          ),
        ],
      ),
    );
  }

  /// One selectable theme swatch in the Appearance picker. Locked streak
  /// themes show a lock and nudge toward the Streak Rewards road on tap.
  Widget _themeTile(AppThemeVariant v, ThemeProvider themeProvider) {
    final palette = AppColors.forVariant(v);
    final reward = streakRewardForVariant(v); // null for light/dark
    final locked = reward != null && !reward.isUnlocked(_longestStreak);
    final active = themeProvider.variant == v;
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        if (locked) {
          _showStyledSnackBar(
            icon: Icons.lock_outline,
            message: context.l10nRead.lockedThemeNudge(reward.days),
            color: const Color(0xFF70798A),
          );
          return;
        }
        themeProvider.setVariant(v);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(color: palette.background),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(color: palette.accent),
                        ),
                      ],
                    ),
                  ),
                  // Selection / lock border.
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? accent : const Color(0x22000000),
                        width: active ? 2 : 1,
                      ),
                    ),
                  ),
                  if (locked)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withValues(alpha: 0.32),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 18, color: Colors.white),
                    ),
                  if (active && !locked)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _variantLabel(v, context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? accent
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9A9DA6)
                        : const Color(0xFF6E727C)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _variantLabel(AppThemeVariant v, BuildContext context) =>
      switch (v) {
        AppThemeVariant.light => context.l10n.themeNameLight,
        AppThemeVariant.dark => context.l10n.themeNameDark,
        AppThemeVariant.smokyIvory => context.l10n.themeNameSmoky,
        AppThemeVariant.seashellMauve => context.l10n.themeNameSeashell,
      };

  /// Bottom sheet to pick the in-app language. Applies immediately and persists
  /// via [LocaleProvider]; the whole app rebuilds in the chosen language.
  void _showLanguageSheet(LocaleProvider localeProvider) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10nRead.language,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ),
            for (final lang in AppLanguage.values)
              ListTile(
                title: Text(
                  lang.nativeName,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  lang.englishName,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                trailing: localeProvider.language == lang
                    ? Icon(Icons.check_circle_rounded, color: colors.accent)
                    : Icon(Icons.circle_outlined, color: colors.textTertiary),
                onTap: () {
                  localeProvider.setLanguage(lang);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }

  /// Ask for a backup passphrase. When [confirm] is true, requires the
  /// passphrase to be entered twice.
  Future<String?> _promptPassphrase({required bool confirm}) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showAppDialog<String>(
      context,
      builder: (ctx) => AppDialog(
        icon: confirm ? Icons.lock_rounded : Icons.lock_open_rounded,
        title: confirm
            ? context.l10nRead.setBackupPassphrase
            : context.l10nRead.enterPassphrase,
        subtitle: confirm
            ? context.l10nRead.setPassphraseDesc
            : context.l10nRead.enterPassphraseDesc,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: context.l10nRead.passphrase),
                validator: (v) => (v == null || v.length < 6)
                    ? context.l10nRead.atLeast6Chars
                    : null,
              ),
              if (confirm) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.l10nRead.confirmPassphrase,
                  ),
                  validator: (v) => v != controller.text
                      ? context.l10nRead.passphrasesDontMatch
                      : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10nRead.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: Text(context.l10nRead.commonContinue),
          ),
        ],
      ),
    );
    controller.dispose();
    confirmController.dispose();
    return result;
  }

  void _showProgressDialog(String message) {
    // The old inline version rendered a bare Container with no Material
    // ancestor, so its text showed in the debug "missing font" style.
    showAppProgressDialog(context, message);
  }

  Future<void> _createBackup() async {
    final passphrase = await _promptPassphrase(confirm: true);
    if (passphrase == null || !mounted) return;

    _showProgressDialog(context.l10nRead.encryptingBackup);
    try {
      final path = await _backupService.createBackup(passphrase);
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      if (path == null) return; // user cancelled the save dialog
      _showStyledSnackBar(
        icon: Icons.check_circle,
        message: context.l10nRead.encryptedBackupSaved,
        color: const Color(0xFF2AA76F),
        actionLabel: context.l10nRead.open,
        onAction: () => OpenFilex.open(path),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.backupFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final passphrase = await _promptPassphrase(confirm: false);
    if (passphrase == null || !mounted) return;

    _showProgressDialog(context.l10nRead.decryptingRestoring);
    try {
      final result = await _backupService.restoreBackup(passphrase);
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      if (result == null) return; // user cancelled the file picker
      // The restore rewrote the database; tell the (still-alive) Home tab and
      // other live screens to reload so counts/totals update without a scan.
      notifyAppDataChanged();
      _showStyledSnackBar(
        icon: Icons.check_circle,
        message: result.total == 0
            ? context.l10nRead.backupRestoredNothing
            : context.l10nRead.restoredSummary(
                result.transactions,
                result.budgets,
                result.rules,
                result.holdings,
                result.sips,
              ),
        color: const Color(0xFF2AA76F),
      );
    } on BackupException catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.lock_outline,
          message: e.message,
          color: const Color(0xFFD25A5F),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.restoreFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
    }
  }

  Future<void> _openExportSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final request = await showModalBottomSheet<ExportRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF16181E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ExportOptionsSheet(),
    );
    if (request == null || !mounted) return;
    await _runExport(request);
  }

  Future<void> _runExport(ExportRequest request) async {
    // Request storage permission
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (mounted) {
            _showStyledSnackBar(
              icon: Icons.error_outline,
              message: context.l10nRead.storagePermissionRequired,
              color: const Color(0xFFD25A5F),
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;
    _showProgressDialog(context.l10nRead.exporting);

    try {
      final path = await _exportService.export(
        format: request.format,
        filter: request.filter,
      );

      if (mounted) Navigator.pop(context); // dismiss loading
      if (!mounted) return;

      if (path == null) {
        _showStyledSnackBar(
          icon: Icons.filter_alt_off_outlined,
          message: context.l10nRead.noTxnMatchFilters,
          color: const Color(0xFFD79A3C),
        );
        return;
      }

      final fileName = path.split('/').last;
      _showStyledSnackBar(
        icon: Icons.check_circle,
        message: context.l10nRead.savedToDownloads(fileName),
        color: const Color(0xFF2AA76F),
        actionLabel: context.l10nRead.open,
        onAction: () => OpenFilex.open(path),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.exportFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
    }
  }

  /// Thin wrapper kept for the backup/restore/export call sites; delegates
  /// to the shared app-themed toast.
  void _showStyledSnackBar({
    required IconData icon,
    required String message,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToastType type;
    if (color == const Color(0xFF2AA76F)) {
      type = AppToastType.success;
    } else if (color == const Color(0xFFD79A3C)) {
      type = AppToastType.warning;
    } else {
      type = AppToastType.error;
    }
    showAppToast(
      context,
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
