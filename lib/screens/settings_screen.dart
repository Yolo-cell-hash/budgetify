import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../app_info.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/plus_products.dart';
import '../models/statement_import_models.dart';
import '../models/streak_reward.dart';
import '../providers/theme_provider.dart';
import '../providers/app_preferences.dart';
import '../providers/locale_provider.dart';
import '../services/app_events.dart';
import '../services/app_lock_service.dart';
import '../services/axio_import_service.dart';
import '../services/backup_service.dart';
import '../services/background_service.dart';
import '../services/entitlement_service.dart';
import '../services/gamification_service.dart';
import '../services/statement_import_service.dart';
import '../services/database_service.dart';
import '../services/rating_prompt_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/export_options_sheet.dart';
import '../widgets/import_options_sheet.dart';
import '../widgets/theme_preview_sheet.dart';
import 'auto_tag_rules_screen.dart';
import 'manage_tags_screen.dart';
import 'plus_screen.dart';
import 'statement_import_screen.dart';
import 'streak_rewards_screen.dart';
import 'tax_screen.dart';

/// Settings screen with theme toggle and auto-scan configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AxioImportService _importService = AxioImportService();
  final BackupService _backupService = BackupService();
  bool _autoScanEnabled = true;
  int _scanIntervalHours = BackgroundService.defaultIntervalHours;
  DateTime? _lastScanTime;
  bool _appLockEnabled = false;
  bool _loading = true;
  int _longestStreak = 0;

  // Guided-tour anchors: the three Intelligence power-up cards, the Backup
  // section header and the Appearance section header.
  final GlobalKey _tutAiKey = GlobalKey();
  final GlobalKey _tutHealthDetailKey = GlobalKey();
  final GlobalKey _tutGamifiedKey = GlobalKey();
  final GlobalKey _tutBackupKey = GlobalKey();
  final GlobalKey _tutAppearanceKey = GlobalKey();

  /// How many message shapes are currently muted, shown beside "Ignored
  /// messages" so the effect of "Not a transaction" is visible after the fact.
  int _mutedShapeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadMutedShapeCount();
    TutorialService.instance.addListener(_onTutorialTick);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowTutorialTip());
  }

  Future<void> _loadMutedShapeCount() async {
    final n = await DatabaseService().countMessageMutes();
    if (mounted) setState(() => _mutedShapeCount = n);
  }

  @override
  void dispose() {
    TutorialService.instance.removeListener(_onTutorialTick);
    super.dispose();
  }

  void _onTutorialTick() {
    if (mounted) _maybeShowTutorialTip();
  }

  /// The tour's last two stops: the Intelligence power-ups, then the
  /// personalisation section — finishing sends the user gently back Home.
  void _maybeShowTutorialTip() {
    if (!mounted) return;
    if (mainShellTabIndex.value != 4) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final svc = TutorialService.instance;
    final l10n = context.l10nRead;
    if (svc.isAt(TutorialStep.settingsAi)) {
      TutorialTips.show(
        context,
        step: TutorialStep.settingsAi,
        anchor: _tutAiKey,
        title: l10n.tutSettingsAiTitle,
        message: l10n.tutSettingsAiBody,
        passthrough: false,
        buttonLabel: l10n.tutNext,
        onButton: () =>
            TutorialService.instance.advanceFrom(TutorialStep.settingsAi),
        advanceIfMissing: true,
      );
    } else if (svc.isAt(TutorialStep.settingsHealth)) {
      TutorialTips.show(
        context,
        step: TutorialStep.settingsHealth,
        anchor: _tutHealthDetailKey,
        title: l10n.tutSettingsHealthTitle,
        message: l10n.tutSettingsHealthBody,
        passthrough: false,
        buttonLabel: l10n.tutNext,
        onButton: () =>
            TutorialService.instance.advanceFrom(TutorialStep.settingsHealth),
        advanceIfMissing: true,
      );
    } else if (svc.isAt(TutorialStep.settingsGamified)) {
      TutorialTips.show(
        context,
        step: TutorialStep.settingsGamified,
        anchor: _tutGamifiedKey,
        title: l10n.tutSettingsGamifiedTitle,
        message: l10n.tutSettingsGamifiedBody,
        passthrough: false,
        buttonLabel: l10n.tutNext,
        onButton: () => TutorialService.instance
            .advanceFrom(TutorialStep.settingsGamified),
        advanceIfMissing: true,
      );
    } else if (svc.isAt(TutorialStep.settingsData)) {
      TutorialTips.show(
        context,
        step: TutorialStep.settingsData,
        anchor: _tutBackupKey,
        title: l10n.tutSettingsDataTitle,
        message: l10n.tutSettingsDataBody,
        passthrough: false,
        buttonLabel: l10n.tutNext,
        onButton: () =>
            TutorialService.instance.advanceFrom(TutorialStep.settingsData),
        advanceIfMissing: true,
      );
    } else if (svc.isAt(TutorialStep.settingsMore)) {
      TutorialTips.show(
        context,
        step: TutorialStep.settingsMore,
        anchor: _tutAppearanceKey,
        title: l10n.tutSettingsMoreTitle,
        message: l10n.tutSettingsMoreBody,
        passthrough: false,
        buttonLabel: l10n.tutFinish,
        onButton: () {
          TutorialService.instance.advanceFrom(TutorialStep.settingsMore);
          showAppToast(
            context,
            message: context.l10nRead.tutDoneToast,
            type: AppToastType.success,
          );
          // Close the loop where it began — a soft cross-fade back Home.
          mainShellTabRequest.value = 0;
        },
        advanceIfMissing: true,
      );
    }
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
    final colors = AppColors.of(context);
    // Brightness still decides one thing here — cards carry a drop shadow only
    // on a light canvas. Every colour comes from the palette above, so the
    // reward themes dress this screen like any other.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.settingsTitle,
            icon: Icons.settings_rounded),
      ),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Budgetify Plus Section — the answer to "where do I actually buy
          // this?", and absent for as long as that question has no answer.
          _buildPlusSection(isDark),

          // Appearance Section
          KeyedSubtree(
            key: _tutAppearanceKey,
            child: _buildSectionHeader(context.l10n.appearance),
          ),
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
                        color: colors.text,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                  // Horizontal "slider": fixed-width tiles (sized as when there
                  // were ~5 themes) that scroll, so 7+ themes never cram.
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (final v in AppThemeVariant.values)
                          SizedBox(
                            width: 72,
                            child: _themeTile(v, themeProvider),
                          ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: colors.border,
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
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textTertiary,
                  ),
                  onTap: () => showLanguagePickerSheet(context, localeProvider),
                ),
                Divider(
                  height: 1,
                  color: colors.border,
                ),
                ListTile(
                  leading: Icon(
                    Icons.local_fire_department_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(context.l10n.streakRewards),
                  subtitle: Text(
                    context.l10n.streakRewardsUnlocked(
                      unlockedStreakRewards(_longestStreak).length,
                      kStreakRewards.length,
                    ),
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textTertiary,
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
          _buildSectionHeader(context.l10n.autoScanSection),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.schedule_rounded,
                    color: _autoScanEnabled ? Color(0xFF2AA76F) : colors.textSecondary,
                  ),
                  title: Text(context.l10n.autoScanTitle),
                  subtitle: Text(
                    _autoScanEnabled
                        ? context.l10n.autoScanOnDesc
                        : context.l10n.autoScanOffDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
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
                    color: colors.border,
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
                            color: colors.text,
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
                                  // A selected chip is filled with the theme's
                                  // accent, so its label is an on-accent
                                  // colour — and every theme already declares
                                  // one (each royal hand-picks its own ink).
                                  color: selected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                      : (colors.textSecondary),
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
                      color: colors.border,
                    ),
                    ListTile(
                      leading: Icon(Icons.history_rounded, color: colors.textSecondary),
                      title: Text(context.l10n.lastScan),
                      subtitle: Text(
                        DateFormat(
                          'MMM d, yyyy • h:mm a',
                        ).format(_lastScanTime!),
                        style: TextStyle(
                          color: colors.textSecondary,
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
          _buildSectionHeader(context.l10n.securitySection),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.fingerprint_rounded,
                    color: _appLockEnabled
                        ? AppColors.of(context).brandAccent
                        : colors.textSecondary,
                  ),
                  title: Text(context.l10n.appLock),
                  subtitle: Text(
                    _appLockEnabled
                        ? context.l10n.appLockOnDesc
                        : context.l10n.appLockOffDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                  value: _appLockEnabled,
                  onChanged: _loading ? null : _toggleAppLock,
                ),
                Divider(
                  height: 1,
                  color: colors.border,
                ),
                SwitchListTile(
                  secondary: Icon(
                    context.watch<AppPreferences>().privacyMode
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: context.watch<AppPreferences>().privacyMode
                        ? AppColors.of(context).brandAccent
                        : colors.textSecondary,
                  ),
                  title: Text(context.l10n.hideAmounts),
                  subtitle: Text(
                    context.l10n.hideAmountsDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
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
          _buildSectionHeader(context.l10n.intelligenceSection),
          const SizedBox(height: 8),
          _buildSettingsCard(
            key: _tutAiKey, // guided-tour anchor
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                Icons.insights_rounded,
                color: context.watch<AppPreferences>().aiPredictionMode
                    ? AppColors.of(context).brandAccent
                    : colors.textSecondary,
              ),
              title: Text(context.l10n.aiPredictionMode),
              subtitle: Text(
                context.l10n.aiPredictionModeDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              value: context.watch<AppPreferences>().aiPredictionMode,
              onChanged: _onAiPredictionChanged,
            ),
          ),

          const SizedBox(height: 12),
          _buildSettingsCard(
            key: _tutHealthDetailKey, // guided-tour anchor
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                Icons.monitor_heart_outlined,
                color: context.watch<AppPreferences>().financialHealthDetailed
                    ? AppColors.of(context).brandAccent
                    : colors.textSecondary,
              ),
              title: Text(context.l10n.detailedFinancialHealth),
              subtitle: Text(
                context.l10n.detailedFinancialHealthDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              value: context.watch<AppPreferences>().financialHealthDetailed,
              onChanged: _onDetailedHealthChanged,
            ),
          ),

          const SizedBox(height: 12),
          _buildSettingsCard(
            key: _tutGamifiedKey, // guided-tour anchor
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                Icons.emoji_events_outlined,
                color: context.watch<AppPreferences>().gamifiedMode
                    ? AppColors.of(context).brandAccent
                    : colors.textSecondary,
              ),
              title: Text(context.l10n.gamifiedBudgets),
              subtitle: Text(
                context.l10n.gamifiedBudgetsDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              value: context.watch<AppPreferences>().gamifiedMode,
              onChanged: _onGamifiedChanged,
            ),
          ),

          const SizedBox(height: 24),

          // Backup Section
          KeyedSubtree(
            key: _tutBackupKey,
            child: _buildSectionHeader(context.l10n.backupSection),
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.shield_moon_outlined,
                    color: AppColors.of(context).brandAccent,
                  ),
                  title: Text(context.l10n.createBackup),
                  subtitle: Text(
                    context.l10n.createBackupDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _createBackup,
                ),
                Divider(
                  height: 1,
                  color: colors.border,
                ),
                ListTile(
                  leading: Icon(
                    Icons.settings_backup_restore_rounded,
                    color: colors.success,
                  ),
                  title: Text(context.l10n.restoreBackup),
                  subtitle: Text(
                    context.l10n.restoreBackupDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _restoreBackup,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader(context.l10n.dataSection),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(Icons.sell_outlined, color: Color(0xFFC68A2E)),
              title: Text(context.l10n.manageTags),
              subtitle: Text(
                context.l10n.manageTagsDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageTagsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // The standing rules "Apply to All" writes. They used to be
          // invisible — created in one tap, then permanent and unlistable —
          // so a tag applied by mistake kept coming back with no way to stop
          // it short of deleting the tag itself.
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading:
                  const Icon(Icons.rule_folder_outlined, color: Color(0xFF4A6489)),
              title: Text(context.l10n.autoTagRules),
              subtitle: Text(
                context.l10n.autoTagRulesDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutoTagRulesScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Tax deductions: tag deductible spends into 80C/80D/… buckets and
          // total them for the filing season. An organiser, not tax advice.
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading:
                  const Icon(Icons.receipt_long_outlined, color: Color(0xFF2AA76F)),
              title: Text(context.l10n.taxDeductions),
              subtitle: Text(
                context.l10n.taxDeductionsDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaxScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Message shapes the user told the parser to skip ("not a
          // transaction — ignore similar"), with per-row un-mute.
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading:
                  const Icon(Icons.notifications_off_outlined, color: Color(0xFFC0392B)),
              title: Text(context.l10n.ignoredMessages),
              subtitle: Text(
                context.l10n.ignoredMessagesTagline,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              // The count makes the mute visible after the fact: choosing
              // "Not a transaction" silently changes what gets logged, so the
              // user should be able to see how many shapes they've muted —
              // and undo one — without opening the list to find out.
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mutedShapeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.of(context)
                            .warning
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.l10n.nMutedShapes(_mutedShapeCount),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.of(context).warning,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: _openIgnoredMessagesSheet,
            ),
          ),

          const SizedBox(height: 24),

          // Import & Export Section
          _buildSectionHeader(context.l10n.importExportSection),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(Icons.download_outlined, color: Color(0xFF6C4CF1)),
              title: Text(context.l10n.importData),
              subtitle: Text(
                context.l10n.importDataDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openImportSheet,
            ),
          ),
          const SizedBox(height: 10),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(Icons.ios_share_rounded, color: Color(0xFF4A6489)),
              title: Text(context.l10n.exportData),
              subtitle: Text(
                context.l10n.exportDataDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openExportSheet,
            ),
          ),

          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader(context.l10n.privacySection),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(
                Icons.shield_outlined,
                color: colors.success,
              ),
              title: Text(context.l10n.dataPrivateTitle),
              subtitle: Text(
                context.l10n.dataPrivateDesc,
                style: TextStyle(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context.l10n.aboutSection),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Budgetify'),
                  subtitle: Text(context.l10n.versionLabel(kAppVersion)),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.border,
                ),
                // Restart the guided tour anytime — its first tip picks the
                // user up on the Home tab.
                ListTile(
                  leading: const Icon(Icons.tour_outlined),
                  title: Text(context.l10n.appTourTitle),
                  subtitle: Text(
                    context.l10n.appTourDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    TutorialService.instance.restart();
                    mainShellTabRequest.value = 0;
                  },
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.border,
                ),
                // Opens the Play listing rather than the in-app rating card:
                // that card is quota-limited and may show nothing at all, which
                // would make a row the user deliberately tapped look broken.
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: Text(context.l10n.rateAppTitle),
                  subtitle: Text(
                    context.l10n.rateAppDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => RatingPromptService.instance.openStoreListing(),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Enabling Gamified Budgets sends the user Home and spotlights the new
  /// Rewards avatar there, so the feature's entry point is obvious right away.
  /// Turning it off is silent.
  Future<void> _onGamifiedChanged(bool enabled) async {
    await context.read<AppPreferences>().setGamifiedMode(enabled);
    if (!enabled) return;
    homeSpotlightRequest.value = 'rewards';
    mainShellTabRequest.value = 0;
  }

  /// Same hand-off for AI Prediction Mode: cross-fade Home and spotlight the
  /// Insights card that just appeared. Turning it off is silent.
  Future<void> _onAiPredictionChanged(bool enabled) async {
    // Plus gate (dormant during the free window): turning the mode ON is
    // Plus-only. Turning it OFF is never gated — a lapsed user must always be
    // able to undo a setting, even one they can no longer re-enable.
    if (enabled &&
        !await PlusScreen.maybePush(context, PlusFeature.aiPredictionMode)) {
      return;
    }
    if (!mounted) return;
    await context.read<AppPreferences>().setAiPredictionMode(enabled);
    if (!enabled) return;
    homeSpotlightRequest.value = 'insights';
    mainShellTabRequest.value = 0;
  }

  /// And for Detailed Financial Health: cross-fade Home and spotlight the
  /// full breakdown card. Turning it off is silent.
  Future<void> _onDetailedHealthChanged(bool enabled) async {
    await context.read<AppPreferences>().setFinancialHealthDetailed(enabled);
    if (!enabled) return;
    homeSpotlightRequest.value = 'health';
    mainShellTabRequest.value = 0;
  }

  /// Opens the still of [v] — the marquee card and canvas together, which is
  /// the part the two-colour swatch cannot show.
  void _previewTheme(
    AppThemeVariant v,
    ThemeProvider themeProvider, {
    StreakReward? reward,
    required bool locked,
  }) {
    showThemePreviewSheet(
      context,
      variant: v,
      name: _variantLabel(v, context),
      unlockDays: locked ? reward!.days : null,
      active: themeProvider.variant == v,
      onApply: locked || themeProvider.variant == v
          ? null
          : () => themeProvider.setVariant(v),
    );
  }

  /// One selectable theme swatch in the Appearance picker. Tapping applies an
  /// unlocked theme; the eye button under any tile opens a full still first.
  Widget _themeTile(AppThemeVariant v, ThemeProvider themeProvider) {
    // [palette] is the variant this tile is advertising; [colors] is the theme
    // the user is currently wearing, which dresses the tile's own label.
    final palette = AppColors.forVariant(v);
    final colors = AppColors.of(context);
    final reward = streakRewardForVariant(v); // null for light/dark
    final locked = reward != null && !reward.isUnlocked(_longestStreak);
    final active = themeProvider.variant == v;
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      // A locked tile opens the preview instead of a snackbar that only
      // restated the lock. "Come back in 60 days" was asking for patience
      // toward something the user had never been shown.
      onTap: () {
        if (locked) {
          _previewTheme(v, themeProvider, reward: reward, locked: true);
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
                        child: const Icon(Icons.check_rounded,
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
                    : colors.textSecondary,
              ),
            ),
            // The "try" affordance, on every tile including the unlocked ones —
            // an earned theme is just as unseen as a locked one until you wear
            // it. An icon rather than a word because the tile is 72px wide and
            // "Preview" translates long; the sheet itself carries the wording.
            Tooltip(
              message: context.l10n.themePreviewAction,
              child: InkResponse(
                onTap: () => _previewTheme(
                  v,
                  themeProvider,
                  reward: reward,
                  locked: locked,
                ),
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    semanticLabel: context.l10n.themePreviewAction,
                    color: colors.textTertiary,
                  ),
                ),
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
        AppThemeVariant.onyxAmber => context.l10n.themeNameAmber,
        AppThemeVariant.royalIndigo => context.l10n.themeNameRoyalIndigo,
        AppThemeVariant.midnightIndigo => context.l10n.themeNameMidnightIndigo,
        AppThemeVariant.vellum => context.l10n.themeNameVellum,
      };

  /// The Budgetify Plus section — where a lapsed user goes to buy.
  ///
  /// Deliberately ABSENT while the free window runs and nothing is owned: no
  /// gate has bitten yet, so an upgrade row would be selling the user
  /// something they already have. It appears the day access lapses, alongside
  /// the feature gates it is the calm alternative to.
  Widget _buildPlusSection(bool isDark) {
    final entitlements = EntitlementService();
    final owned = entitlements.hasPlus;
    if (entitlements.trialActive && !owned) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(context.l10n.plusTitle),
        const SizedBox(height: 8),
        _buildSettingsCard(
          isDark: isDark,
          child: _buildPlusTile(owned: owned),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// The row itself. Two states:
  ///
  ///   * **owned** — a plain confirmation with no chevron and no tap. Sending
  ///     a paying user back to a screen that sells what they already own is
  ///     the one version of this row that would feel like a shakedown.
  ///   * **lapsed** — the ask, named in terms of what comes back rather than
  ///     what was taken away.
  Widget _buildPlusTile({required bool owned}) {
    final colors = AppColors.of(context);
    return ListTile(
      leading: Icon(
        owned ? Icons.workspace_premium_rounded : Icons.auto_awesome_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(context.l10n.plusTitle),
      subtitle: Text(
        owned
            ? context.l10n.plusSettingsOwnedDesc
            : context.l10n.plusSettingsLockedDesc,
        style: TextStyle(
          color: colors.textSecondary,
        ),
      ),
      trailing: owned ? null : const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: owned ? null : _openPlusScreen,
    );
  }

  /// Open the paywall, then rebuild — a purchase or a restore made on that
  /// screen changes what this row should say.
  Future<void> _openPlusScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlusScreen()),
    );
    if (mounted) setState(() {});
  }

  Widget _buildSectionHeader(String title) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
      {Key? key, required bool isDark, required Widget child}) {
    final colors = AppColors.of(context);
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: colors.card,
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
        icon: Icons.check_circle_rounded,
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
        icon: Icons.check_circle_rounded,
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

  /// Bottom sheet listing message shapes the user muted via "Not a
  /// transaction — ignore similar". Deleting a row un-mutes that shape.
  Future<void> _openIgnoredMessagesSheet() async {
    // Un-muting inside the sheet changes the count behind it.
    await _showIgnoredMessagesSheet();
    await _loadMutedShapeCount();
  }

  Future<void> _showIgnoredMessagesSheet() async {
    final colors = AppColors.of(context);
    final cardColor = colors.card;
    final textColor = colors.text;
    final subtextColor =
        colors.textSecondary;
    final db = DatabaseService();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.ignoredMessages,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ctx.l10n.ignoredMessagesTagline,
                  style: TextStyle(fontSize: 13, color: subtextColor),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: FutureBuilder<List<Map<String, Object?>>>(
                    future: db.listMessageMutes(),
                    builder: (ctx, snapshot) {
                      final mutes = snapshot.data ?? const [];
                      if (snapshot.connectionState !=
                          ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (mutes.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              ctx.l10n.noIgnoredMessages,
                              style: TextStyle(color: subtextColor),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: mutes.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: colors.border,
                        ),
                        itemBuilder: (ctx, i) {
                          final mute = mutes[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              mute['sender_core'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              mute['sample'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Color(0xFFC0392B),
                              ),
                              onPressed: () async {
                                await db
                                    .deleteMessageMute(mute['id'] as int);
                                setSheetState(() {});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openImportSheet() async {
    final colors = AppColors.of(context);
    final source = await showModalBottomSheet<ImportSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ImportSourceSheet(),
    );
    if (source == null || !mounted) return;
    switch (source) {
      case ImportSource.axio:
        await _runAxioImport();
      case ImportSource.bankStatement:
        await _runStatementImport();
    }
  }

  /// Pick a bank-statement CSV/XLSX, decode it, and hand off to the mapping /
  /// review flow. All errors surface as calm toasts; nothing is written until
  /// the user confirms inside the screen.
  Future<void> _runStatementImport() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'txt', 'tsv', 'pdf'],
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.importFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
      return;
    }
    final file =
        (picked == null || picked.files.isEmpty) ? null : picked.files.first;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    List<List<String>> grid;
    try {
      grid = StatementImportService.decodeBytes(bytes);
    } on StatementFileException catch (e) {
      final l10n = context.l10nRead;
      _showStyledSnackBar(
        icon: Icons.description_outlined,
        message: switch (e.kind) {
          StatementFileKind.pdf => l10n.stPdfComingSoon,
          StatementFileKind.legacyXls => l10n.stXlsUnsupported,
          StatementFileKind.unreadable => l10n.stNoTable,
        },
        color: const Color(0xFFD79A3C),
      );
      return;
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.importFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
      return;
    }

    final detected = StatementImportService.detectHeader(grid);
    if (detected == null) {
      _showStyledSnackBar(
        icon: Icons.table_rows_outlined,
        message: context.l10nRead.stNoTable,
        color: const Color(0xFFD79A3C),
      );
      return;
    }

    // "HDFC_statement-May.csv" → "HDFC statement May" as the suggested label.
    var suggested = file.name
        .replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '')
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .trim();
    if (suggested.length > 24) suggested = suggested.substring(0, 24).trim();

    final result = await Navigator.push<StatementImportResult>(
      context,
      MaterialPageRoute(
        builder: (_) => StatementImportScreen(
          grid: grid,
          headerRowIndex: detected.rowIndex,
          initialMapping: detected.mapping,
          suggestedLabel: suggested.isEmpty ? 'Statement' : suggested,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _showStyledSnackBar(
      icon: Icons.check_circle_rounded,
      message: context.l10nRead.stImportedToast(
        result.inserted,
        result.autoTagged,
      ),
      color: const Color(0xFF2AA76F),
    );
  }

  Future<void> _runAxioImport() async {
    // Let the user pick their axio CSV export.
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.importFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
      return;
    }
    final bytes = (picked == null || picked.files.isEmpty)
        ? null
        : picked.files.first.bytes;
    if (bytes == null || !mounted) return;

    // Read + parse (never inserts anything yet).
    AxioImportPreview preview;
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      preview = _importService.parsePreview(content);
    } on FormatException {
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.description_outlined,
          message: context.l10nRead.importInvalidFile,
          color: const Color(0xFFD79A3C),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.importFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
      return;
    }

    if (!mounted) return;
    if (preview.isEmpty) {
      _showStyledSnackBar(
        icon: Icons.info_outline,
        message: context.l10nRead.importNoTags,
        color: const Color(0xFFD79A3C),
      );
      return;
    }

    // Show exactly what will happen before touching the database.
    final colors = AppColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AxioImportPreviewSheet(preview: preview),
    );
    if (confirmed != true || !mounted) return;

    _showProgressDialog(context.l10nRead.importing);
    try {
      final result = await _importService.apply(preview);
      if (mounted) Navigator.pop(context); // dismiss progress
      if (!mounted) return;
      _showStyledSnackBar(
        icon: Icons.check_circle_rounded,
        message: context.l10nRead.importDone(
          result.rulesCreated + result.rulesUpdated,
          result.transactionsTagged,
        ),
        color: const Color(0xFF2AA76F),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss progress
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: context.l10nRead.importFailed('$e'),
          color: const Color(0xFFD25A5F),
        );
      }
    }
  }

  Future<void> _openExportSheet() => showExportSheet(context);

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
