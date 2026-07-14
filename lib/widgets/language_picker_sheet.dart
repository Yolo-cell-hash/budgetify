import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

/// Bottom sheet to pick the in-app language. Applies immediately and persists
/// via [LocaleProvider]; the whole app rebuilds in the chosen language.
///
/// The option list lives inside a [Flexible] scroll view: a modal sheet is
/// capped at ~9/16 of the screen, and a fixed column of six languages used to
/// overflow that cap on smaller phones — clipping the last language half out
/// of view. Now the list scrolls whenever it doesn't fit.
void showLanguagePickerSheet(BuildContext context, LocaleProvider localeProvider) {
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
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
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
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    trailing: localeProvider.language == lang
                        ? Icon(Icons.check_circle_rounded, color: colors.accent)
                        : Icon(Icons.circle_outlined,
                            color: colors.textTertiary),
                    onTap: () {
                      localeProvider.setLanguage(lang);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
