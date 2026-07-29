import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// User-chosen names for the banks Budgetify detects.
///
/// The detected identity is what everything is wired to — an alias only
/// changes the words on screen. "HDFC Bank" can read "HDFC Salary", and a
/// header we couldn't name ("ZZZTOP") can read whatever the user calls that
/// account; both keep resolving from the same sender header, so renaming
/// never moves a rupee between rows.
///
/// Keyed on [BankIdentity.id], which is the grouping key: one alias covers
/// every header the bank sends from, so naming "State Bank of India" once
/// renames all 273 of its headers at a stroke.
///
/// Same shape as [CustomTagService]: a singleton with a static cache filled
/// once at startup, so lookups are synchronous and the export path (which
/// resolves names deep inside a sync build) needs no plumbing.
class BankAliasService {
  static const String _storageKey = 'bank_aliases';

  static final BankAliasService _instance = BankAliasService._internal();
  static Map<String, String> _aliases = {};
  static bool _initialized = false;

  factory BankAliasService() => _instance;
  BankAliasService._internal();

  /// Load saved names. Call once at app startup, before anything renders.
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromStorage();
    _initialized = true;
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        _aliases = {};
        return;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _aliases = {
        for (final entry in decoded.entries)
          if (entry.value is String && (entry.value as String).trim().isNotEmpty)
            entry.key: (entry.value as String).trim(),
      };
    } catch (_) {
      // A corrupt blob must not take the app down — fall back to detected
      // names, which are always derivable from the sender.
      _aliases = {};
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_aliases));
  }

  /// The user's name for [bankId], or null when they haven't renamed it.
  String? aliasFor(String bankId) => _aliases[bankId];

  /// Every alias on record, for backup and the manage screen.
  Map<String, String> get all => Map.unmodifiable(_aliases);

  bool get isEmpty => _aliases.isEmpty;

  /// Name [bankId]. A blank name clears the alias and restores the detected
  /// name, so there is always a way back.
  Future<void> setAlias(String bankId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return clearAlias(bankId);
    }
    _aliases[bankId] = trimmed;
    await _saveToStorage();
  }

  /// Drop the user's name for [bankId] and go back to what was detected.
  Future<void> clearAlias(String bankId) async {
    if (_aliases.remove(bankId) == null) return;
    await _saveToStorage();
  }

  /// The names, for a backup payload.
  Map<String, dynamic> exportSettings() => {'aliases': Map.of(_aliases)};

  /// Restore names from a backup payload (merges, doesn't clobber).
  ///
  /// A restore is additive everywhere else in the app — transactions dedupe
  /// by fingerprint, tags are added not replaced — so names the user set on
  /// *this* device must survive restoring a backup that predates them. Where
  /// both sides name the same bank, the backup wins, matching how tag emoji
  /// overrides resolve.
  Future<void> importSettings(Map<String, dynamic>? settings) async {
    if (settings == null) return;
    final aliases = settings['aliases'];
    if (aliases is! Map) return;
    var changed = false;
    for (final entry in aliases.entries) {
      final key = entry.key?.toString();
      final value = entry.value;
      if (key == null || key.isEmpty || value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      _aliases[key] = trimmed;
      changed = true;
    }
    if (changed) await _saveToStorage();
  }

  /// Test seam: drop the cache so each test starts clean.
  static void resetForTest([Map<String, String>? seed]) {
    _aliases = {...?seed};
    _initialized = seed != null;
  }
}
