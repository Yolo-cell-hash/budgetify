import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static final CustomTagService _instance = CustomTagService._internal();
  static List<CustomTag> _cachedTags = [];
  static bool _initialized = false;

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
  Future<bool> addCustomTag(String name, String emoji) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    // Check for duplicates (case-insensitive)
    if (_cachedTags.any(
      (t) => t.name.toLowerCase() == trimmedName.toLowerCase(),
    )) {
      return false;
    }

    _cachedTags.add(CustomTag(name: trimmedName, emoji: emoji));
    await _saveToStorage();
    return true;
  }

  /// Delete a custom tag by name.
  Future<void> deleteCustomTag(String name) async {
    _cachedTags.removeWhere(
      (t) => t.name.toLowerCase() == name.toLowerCase(),
    );
    await _saveToStorage();
  }

  /// Get the emoji for a tag name. Returns null if not a custom tag.
  String? getTagEmoji(String name) {
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
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_cachedTags.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }
}
