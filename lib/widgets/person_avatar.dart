import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';

/// A premium circular avatar for a person in the split ledger. The user is
/// shown as a champagne-gold person glyph; everyone else gets their initials
/// over a soft, deterministic colour derived from their name — no emoji, and
/// consistent wherever the person appears.
class PersonAvatar extends StatelessWidget {
  final String name;
  final bool isMe;
  final double size;

  const PersonAvatar({
    super.key,
    required this.name,
    this.isMe = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isMe ? AppColors.of(context).brandAccent : CustomTagService.colorFromName(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.24),
            color.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: isMe
          ? Icon(Icons.person_rounded, size: size * 0.5, color: color)
          : Text(
              initials(name),
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
    );
  }

  /// Up to two initials from a name ("Rohan Sharma" → "RS", "Priya" → "P").
  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
