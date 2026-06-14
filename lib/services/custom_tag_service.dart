import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart' show ExpenseCategories;

/// A custom tag created by the user, with a name and emoji.
class CustomTag {
  final String name;
  final String emoji;

  const CustomTag({required this.name, required this.emoji});

  Map<String, dynamic> toJson() => {'name': name, 'emoji': emoji};

  factory CustomTag.fromJson(Map<String, dynamic> json) => CustomTag(
    name: json['name'] as String,
    emoji: json['emoji'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomTag &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Service for managing custom user-created tags.
/// Tags are stored in SharedPreferences as a JSON array.
class CustomTagService {
  static const String _storageKey = 'custom_tags';
  static const String _overridesKey = 'tag_emoji_overrides';
  static const String _hiddenKey = 'hidden_tags';
  static final CustomTagService _instance = CustomTagService._internal();
  static List<CustomTag> _cachedTags = [];
  static Map<String, String> _emojiOverrides = {};
  static Set<String> _hiddenTags = {}; // lowercased predefined names
  static bool _initialized = false;

  /// Fallback emojis used when a tag is created without choosing one.
  static const List<String> defaultEmojiPool = [
    '🏷️', '✨', '📌', '🎯', '🧩', '🌟', '🔖', '🎟️', '🪙', '🍀', '🎒', '🫧',
  ];

  factory CustomTagService() => _instance;
  CustomTagService._internal();

  /// Initialize and load tags from storage. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromStorage();
    _initialized = true;
  }

  /// Get all custom tags (from cache).
  List<CustomTag> getCustomTags() => List.unmodifiable(_cachedTags);

  /// Add a new custom tag. Returns false if a tag with the same name exists.
  /// When [emoji] is null or empty, one is picked from [defaultEmojiPool].
  Future<bool> addCustomTag(String name, [String? emoji]) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    // Check for duplicates (case-insensitive)
    if (_cachedTags.any(
      (t) => t.name.toLowerCase() == trimmedName.toLowerCase(),
    )) {
      return false;
    }

    final resolvedEmoji = (emoji == null || emoji.trim().isEmpty)
        ? defaultEmojiPool[Random().nextInt(defaultEmojiPool.length)]
        : emoji;

    _cachedTags.add(CustomTag(name: trimmedName, emoji: resolvedEmoji));
    await _saveToStorage();
    return true;
  }

  /// Set a custom emoji for ANY tag — predefined categories included.
  /// Custom tags are updated in place; predefined categories get an
  /// override entry that getTagEmoji (and so ExpenseCategories.getIcon)
  /// resolves first.
  Future<void> setTagEmoji(String name, String emoji) async {
    final index = _cachedTags.indexWhere(
      (t) => t.name.toLowerCase() == name.toLowerCase(),
    );
    if (index >= 0) {
      _cachedTags[index] = CustomTag(
        name: _cachedTags[index].name,
        emoji: emoji,
      );
      await _saveToStorage();
    } else {
      _emojiOverrides[name.toLowerCase()] = emoji;
      await _saveOverrides();
    }
  }

  /// Delete a custom tag by name.
  Future<void> deleteCustomTag(String name) async {
    _cachedTags.removeWhere(
      (t) => t.name.toLowerCase() == name.toLowerCase(),
    );
    await _saveToStorage();
  }

  /// Predefined names the user has hidden ("deleted"). Predefined categories
  /// can't be removed from the const list, so we remember them as hidden and
  /// filter them out of the pickers.
  bool isHidden(String name) => _hiddenTags.contains(name.toLowerCase());

  /// Delete a tag, whether custom or predefined. Custom tags are removed
  /// outright; predefined tags are hidden so they vanish from the pickers.
  /// Any emoji override is also cleared. Callers are responsible for
  /// untagging affected transactions first (see DatabaseService.untagCategory).
  Future<void> deleteTag(String name) async {
    final lower = name.toLowerCase();
    if (isCustomTag(name)) {
      await deleteCustomTag(name);
    } else {
      _hiddenTags.add(lower);
      await _saveHidden();
    }
    if (_emojiOverrides.remove(lower) != null) {
      await _saveOverrides();
    }
  }

  /// Restore a previously hidden predefined tag.
  Future<void> restoreTag(String name) async {
    if (_hiddenTags.remove(name.toLowerCase())) {
      await _saveHidden();
    }
  }

  /// Predefined categories the user has hidden (for a "restore" affordance).
  List<String> get hiddenPredefined => ExpenseCategories.predefined
      .where((c) => _hiddenTags.contains(c.toLowerCase()))
      .toList();

  /// Get the emoji for a tag name. Checks user overrides first (which can
  /// apply to predefined categories), then custom tags. Returns null when
  /// neither has one, letting callers fall back to the built-in icon.
  String? getTagEmoji(String name) {
    final override = _emojiOverrides[name.toLowerCase()];
    if (override != null) return override;
    try {
      return _cachedTags
          .firstWhere(
            (t) => t.name.toLowerCase() == name.toLowerCase(),
          )
          .emoji;
    } catch (_) {
      return null;
    }
  }

  /// Check if a category name is a custom tag.
  bool isCustomTag(String name) {
    return _cachedTags.any(
      (t) => t.name.toLowerCase() == name.toLowerCase(),
    );
  }

  /// Generate a deterministic color from a tag name for chart/graph usage.
  static Color colorFromName(String name) {
    final hash = name.hashCode.abs();
    // Use golden-ratio-based hue distribution for visually distinct colors
    final hue = (hash * 137.508) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.65, 0.55).toColor();
  }

  // ---- Private storage helpers ----

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _cachedTags =
            decoded.map((e) => CustomTag.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error loading custom tags: $e');
        _cachedTags = [];
      }
    }

    final overridesStr = prefs.getString(_overridesKey);
    if (overridesStr != null) {
      try {
        _emojiOverrides = Map<String, String>.from(
          jsonDecode(overridesStr) as Map,
        );
      } catch (e) {
        debugPrint('Error loading emoji overrides: $e');
        _emojiOverrides = {};
      }
    }

    final hiddenStr = prefs.getString(_hiddenKey);
    if (hiddenStr != null) {
      try {
        _hiddenTags = (jsonDecode(hiddenStr) as List)
            .map((e) => e.toString())
            .toSet();
      } catch (e) {
        debugPrint('Error loading hidden tags: $e');
        _hiddenTags = {};
      }
    }
  }

  Future<void> _saveOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overridesKey, jsonEncode(_emojiOverrides));
  }

  Future<void> _saveHidden() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hiddenKey, jsonEncode(_hiddenTags.toList()));
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_cachedTags.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }
}
