import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/theme_provider.dart';
import '../providers/app_preferences.dart';
import '../services/background_service.dart';
import '../services/export_service.dart';

/// Settings screen with theme toggle and auto-scan configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ExportService _exportService = ExportService();
  bool _autoScanEnabled = false;
  String _scanTime1 = '14:55';
  String? _scanTime2 = '22:55';
  DateTime? _lastScanTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await BackgroundService.getScanSettings();
    final lastScan = await BackgroundService.getLastScanTime();
    setState(() {
      _autoScanEnabled = settings['enabled'] as bool;
      _scanTime1 = settings['time1'] as String;
      _scanTime2 = settings['time2'] as String?;
      _lastScanTime = lastScan;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    await BackgroundService.saveScanSettings(
      enabled: _autoScanEnabled,
      time1: _scanTime1,
      time2: _scanTime2,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _autoScanEnabled ? 'Auto-scan enabled' : 'Auto-scan disabled',
          ),
        ),
      );
    }
  }

  String _formatTimeString(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickTime(bool isFirstScan) async {
    final currentTime = isFirstScan ? _scanTime1 : (_scanTime2 ?? '22:55');
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isFirstScan) {
          _scanTime1 = timeString;
        } else {
          _scanTime2 = timeString;
        }
      });
      await _saveSettings();
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
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
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
                    color: _autoScanEnabled ? Colors.green : Colors.grey,
                  ),
                  title: const Text('Automatic SMS Scanning'),
                  subtitle: Text(
                    _autoScanEnabled
                        ? 'Transactions are scanned automatically'
                        : 'Enable to auto-detect transactions in background',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
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
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.blue),
                    title: const Text('First Scan Time'),
                    subtitle: Text(_formatTimeString(_scanTime1)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickTime(true),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.access_time,
                      color: _scanTime2 != null ? Colors.blue : Colors.grey,
                    ),
                    title: const Text('Second Scan Time (Optional)'),
                    subtitle: Text(
                      _scanTime2 != null
                          ? _formatTimeString(_scanTime2!)
                          : 'Tap to add',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_scanTime2 != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () async {
                              setState(() => _scanTime2 = null);
                              await _saveSettings();
                            },
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _pickTime(false),
                  ),
                  if (_lastScanTime != null) ...[
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                    ListTile(
                      leading: Icon(Icons.history, color: Colors.grey.shade500),
                      title: const Text('Last Scan'),
                      subtitle: Text(
                        DateFormat(
                          'MMM d, yyyy • h:mm a',
                        ).format(_lastScanTime!),
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
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
              leading: Icon(Icons.refresh, color: Colors.orange.shade600),
              title: const Text('Reset Onboarding'),
              subtitle: Text(
                'Show first-time setup again',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset Onboarding?'),
                    content: const Text(
                      'This will show the setup wizard on next app launch.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await context.read<AppPreferences>().resetOnboarding();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Onboarding reset. Restart app to see changes.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // Export Section
          _buildSectionHeader('Export', isDark),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.table_chart, color: Colors.blue.shade600),
                  title: const Text('Export as Excel'),
                  subtitle: Text(
                    'Month-wise categorized data (.csv)',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(isExcel: true),
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                ListTile(
                  leading: Icon(Icons.description, color: Colors.teal.shade600),
                  title: const Text('Export as Text'),
                  subtitle: Text(
                    'Formatted summary report (.txt)',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(isExcel: false),
                ),
              ],
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
                color: Colors.green.shade600,
              ),
              title: const Text('Your Data is Private'),
              subtitle: Text(
                'All data stays on your device. We do not collect or upload any information.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
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
              title: Text('Budget Tracker'),
              subtitle: Text('Version 1.0.0'),
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
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
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

  Future<void> _exportData({required bool isExcel}) async {
    // Request storage permission
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        // Try regular storage permission as fallback
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (mounted) {
            _showStyledSnackBar(
              icon: Icons.error_outline,
              message: 'Storage permission is required to export data',
              color: Colors.red,
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1C2333)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Exporting ${isExcel ? 'CSV' : 'TXT'}...',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final path = isExcel
          ? await _exportService.exportToExcel()
          : await _exportService.exportToTxt();

      if (mounted) Navigator.pop(context); // dismiss loading

      // Extract just the filename from the path
      final fileName = path.split('/').last;

      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.check_circle,
          message: 'Saved to Downloads/$fileName',
          color: Colors.green,
          actionLabel: 'Open',
          onAction: () => OpenFilex.open(path),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading
      if (mounted) {
        _showStyledSnackBar(
          icon: Icons.error_outline,
          message: 'Export failed: $e',
          color: Colors.red,
        );
      }
    }
  }

  void _showStyledSnackBar({
    required IconData icon,
    required String message,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [Colors.grey.shade900, Colors.grey.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: color.withAlpha(30),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
