import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../app_info.dart';
import '../providers/theme_provider.dart';
import '../providers/app_preferences.dart';
import '../services/app_events.dart';
import '../services/app_lock_service.dart';
import '../services/backup_service.dart';
import '../services/background_service.dart';
import '../services/export_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/export_options_sheet.dart';
import 'manage_tags_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await BackgroundService.getScanSettings();
    final lastScan = await BackgroundService.getLastScanTime();
    final appLock = await AppLockService().isEnabled();
    setState(() {
      _autoScanEnabled = settings['enabled'] as bool;
      _scanIntervalHours = settings['intervalHours'] as int;
      _lastScanTime = lastScan;
      _appLockEnabled = appLock;
      _loading = false;
    });
  }

  Future<void> _toggleAppLock(bool enable) async {
    final lockService = AppLockService();
    if (enable) {
      if (!await lockService.isDeviceSupported()) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: 'No screen lock or biometrics set up on this device',
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
        message: _autoScanEnabled ? 'Auto-scan enabled' : 'Auto-scan disabled',
        type: _autoScanEnabled ? AppToastType.success : AppToastType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance', isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: Theme.of(context).primaryColor,
              ),
              title: const Text('Dark Mode'),
              subtitle: Text(
                isDark ? 'Switch to light theme' : 'Switch to dark theme',
                style: TextStyle(
                  color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                ),
              ),
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.toggleTheme(),
            ),
          ),

          const SizedBox(height: 24),

          // Auto-Scan Section
          _buildSectionHeader('Auto-Scan', isDark),
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
                  title: const Text('Automatic SMS Scanning'),
                  subtitle: Text(
                    _autoScanEnabled
                        ? 'Transactions are scanned automatically'
                        : 'Enable to auto-detect transactions in background',
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
                          'Scan Frequency',
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
                                label: Text(h == 1 ? 'Hourly' : 'Every ${h}h'),
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
                      title: const Text('Last Scan'),
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
          _buildSectionHeader('Security', isDark),
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
                  title: const Text('App Lock'),
                  subtitle: Text(
                    _appLockEnabled
                        ? 'Unlock with fingerprint, face, or device PIN'
                        : 'Require authentication to open the app',
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
                  title: const Text('Hide Amounts'),
                  subtitle: Text(
                    'Blur all figures until you tap to reveal',
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
          _buildSectionHeader('Intelligence', isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: SwitchListTile(
              secondary: Icon(
                Icons.auto_awesome_rounded,
                color: context.watch<AppPreferences>().aiPredictionMode
                    ? const Color(0xFFA8843C)
                    : const Color(0xFF8A8D96),
              ),
              title: const Text('AI Prediction Mode'),
              subtitle: Text(
                'Show a spending forecast and insights on your dashboard. '
                'Computed entirely on your device — nothing is uploaded.',
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
              title: const Text('Detailed Financial Health'),
              subtitle: Text(
                'Show the full Financial Health card with a per-pillar '
                'breakdown. When off, just the score appears on your balance '
                'card.',
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
              title: const Text('Gamified Budgets'),
              subtitle: Text(
                'Earn achievement badges, titles and a shareable profile from '
                'your spending. Opens a separate Rewards hub from your Home '
                'avatar — everything stays on your device.',
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
          _buildSectionHeader('Backup', isDark),
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
                  title: const Text('Create Encrypted Backup'),
                  subtitle: Text(
                    'All transactions, budgets, rules & tags (AES-256)',
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
                  title: const Text('Restore from Backup'),
                  subtitle: Text(
                    'Merge a backup file into this device',
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
          _buildSectionHeader('Data', isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(Icons.sell_outlined, color: Color(0xFFC68A2E)),
              title: const Text('Manage Tags'),
              subtitle: Text(
                'Delete tags you don\'t use',
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
          ),

          const SizedBox(height: 24),

          // Export Section
          _buildSectionHeader('Export', isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(Icons.ios_share, color: Color(0xFF4A6489)),
              title: const Text('Export Data'),
              subtitle: Text(
                'Excel, CSV, or text — filter by date, type, tag or payee',
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
          _buildSectionHeader('Privacy', isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: ListTile(
              leading: Icon(
                Icons.shield_outlined,
                color: Color(0xFF178A5B),
              ),
              title: const Text('Your Data is Private'),
              subtitle: Text(
                'All data stays on your device. We do not collect or upload any information.',
                style: TextStyle(
                  color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About', isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Budgetify'),
              subtitle: Text('Version $kAppVersion'),
            ),
          ),
        ],
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
        title: confirm ? 'Set Backup Passphrase' : 'Enter Passphrase',
        subtitle: confirm
            ? 'Your backup is encrypted with this passphrase. Without it the '
                  'backup cannot be restored — there is no recovery.'
            : 'Enter the passphrase this backup was created with.',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Passphrase'),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              if (confirm) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm passphrase',
                  ),
                  validator: (v) =>
                      v != controller.text ? 'Passphrases don\'t match' : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const Text('Continue'),
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

    _showProgressDialog('Encrypting backup…');
    try {
      final path = await _backupService.createBackup(passphrase);
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      if (path == null) return; // user cancelled the save dialog
      _showStyledSnackBar(
        icon: Icons.check_circle,
        message: 'Encrypted backup saved',
        color: const Color(0xFF2AA76F),
        actionLabel: 'Open',
        onAction: () => OpenFilex.open(path),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: 'Backup failed: $e',
          color: const Color(0xFFD25A5F),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final passphrase = await _promptPassphrase(confirm: false);
    if (passphrase == null || !mounted) return;

    _showProgressDialog('Decrypting and restoring…');
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
            ? 'Backup restored — everything was already on this device'
            : 'Restored ${result.transactions} transactions, '
                  '${result.budgets} budgets, ${result.rules} rules, '
                  '${result.holdings} holdings, ${result.sips} SIPs',
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
          message: 'Restore failed: $e',
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
              message: 'Storage permission is required to export data',
              color: const Color(0xFFD25A5F),
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;
    _showProgressDialog('Exporting…');

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
          message: 'No transactions match those filters',
          color: const Color(0xFFD79A3C),
        );
        return;
      }

      final fileName = path.split('/').last;
      _showStyledSnackBar(
        icon: Icons.check_circle,
        message: 'Saved to Downloads/$fileName',
        color: const Color(0xFF2AA76F),
        actionLabel: 'Open',
        onAction: () => OpenFilex.open(path),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: 'Export failed: $e',
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
