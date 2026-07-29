import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/custom_tag_service.dart';
import 'app_toast.dart';

/// Emoji palette offered when creating a tag or re-skinning an existing one.
const List<String> kTagEmojiChoices = [
  '🏠', '🎮', '💊', '🎁', '🐾', '🍕', '🏋️', '📱', '☕', '🎵',
  '💇', '🧹', '🚕', '🎓', '👶', '💍', '🏦', '⛽', '🅿️', '📦',
  '🛒', '🍿', '🏥', '✂️', '🧾', '💻', '📸', '🎂', '🌐', '🔧',
];

/// "Create a custom tag" bottom sheet: a name field with the chosen emoji as
/// its prefix, an emoji grid, and a create button. Persists through
/// [CustomTagService] and resolves to the new tag's name, or null if the user
/// backed out (or the name collided with an existing tag).
///
/// Shared by the transaction-detail category grid ("+ New Tag") and
/// Settings → Manage tags, so tag creation behaves identically wherever it is
/// reached from.
Future<String?> showCreateTagSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final nameController = TextEditingController();
  String selectedEmoji = '🏷️';

  final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;
  final subtextColor = isDark ? const Color(0xFF9A9DA6) : const Color(0xFF6E727C);
  final inputBg = isDark ? const Color(0xFF262931) : const Color(0xFFFAFAF8);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9A9DA6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  ctx.l10nRead.createCustomTag,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ctx.l10nRead.createTagDesc,
                  style: TextStyle(color: subtextColor),
                ),
                const SizedBox(height: 20),
                // Tag name input
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: ctx.l10nRead.tagNameHint,
                    hintStyle: TextStyle(color: subtextColor),
                    filled: true,
                    fillColor: inputBg,
                    prefixIcon: Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: Text(
                        selectedEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Emoji picker grid
                Text(
                  ctx.l10nRead.pickAnEmoji,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: kTagEmojiChoices.length,
                    itemBuilder: (_, i) {
                      final emoji = kTagEmojiChoices[i];
                      final isSelected = emoji == selectedEmoji;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() => selectedEmoji = emoji);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4A6489).withAlpha(40)
                                : (isDark
                                    ? const Color(0xFF262931)
                                    : const Color(0xFFF6F6F3)),
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: const Color(0xFF8FA9C7),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final l10n = ctx.l10nRead;
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        showAppToast(ctx,
                            message: l10n.enterTagName,
                            type: AppToastType.warning);
                        return;
                      }
                      final success = await CustomTagService().addCustomTag(
                        name,
                        selectedEmoji,
                      );
                      if (!ctx.mounted) return;
                      if (!success) {
                        showAppToast(ctx,
                            message: l10n.tagExists,
                            type: AppToastType.warning);
                        return;
                      }
                      Navigator.pop(ctx, name);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6489),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      ctx.l10nRead.createTag,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
