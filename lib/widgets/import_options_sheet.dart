import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/axio_import_service.dart';

/// Bottom sheet that lets the user pick which app to import tags from. Pops the
/// chosen [ImportSource], or null if dismissed. Built as a list so new sources
/// slot in without reworking the flow.
class ImportSourceSheet extends StatelessWidget {
  const ImportSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DragHandle(colors: colors),
          const SizedBox(height: 18),
          Text(
            context.l10n.importFromTitle,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.importFromDesc,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _SourceTile(
            colors: colors,
            monogram: 'a',
            monogramColor: const Color(0xFF6C4CF1),
            title: ImportSource.axio.displayName,
            subtitle: context.l10n.importSourceAxioDesc,
            onTap: () => Navigator.pop(context, ImportSource.axio),
          ),
        ],
      ),
    );
  }
}

/// Confirmation sheet summarising what an [AxioImportPreview] will do. Pops
/// true when the user taps Import, null otherwise.
class AxioImportPreviewSheet extends StatelessWidget {
  final AxioImportPreview preview;
  const AxioImportPreviewSheet({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DragHandle(colors: colors),
            const SizedBox(height: 18),
            Text(
              context.l10n.importReviewTitle,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.importFoundMerchants(preview.merchantCount),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preview.recurring.isNotEmpty) ...[
                      _GroupHeader(
                        colors: colors,
                        icon: Icons.repeat_rounded,
                        tint: colors.success,
                        title: context.l10n.importAutoRulesTitle(
                          preview.recurring.length,
                        ),
                        desc: context.l10n.importAutoRulesDesc,
                      ),
                      const SizedBox(height: 10),
                      ...preview.recurring.map(
                        (t) => _MerchantRow(colors: colors, tag: t),
                      ),
                    ],
                    if (preview.oneOff.isNotEmpty) ...[
                      if (preview.recurring.isNotEmpty)
                        const SizedBox(height: 20),
                      _GroupHeader(
                        colors: colors,
                        icon: Icons.touch_app_outlined,
                        tint: colors.accent,
                        title: context.l10n.importOneTimeTitle(
                          preview.oneOff.length,
                        ),
                        desc: context.l10n.importOneTimeDesc,
                      ),
                      const SizedBox(height: 10),
                      ...preview.oneOff.map(
                        (t) => _MerchantRow(colors: colors, tag: t),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(context.l10n.importButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final AppColors colors;
  const _DragHandle({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final AppColors colors;
  final String monogram;
  final Color monogramColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.colors,
    required this.monogram,
    required this.monogramColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: monogramColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                monogram,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: monogramColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final Color tint;
  final String title;
  final String desc;

  const _GroupHeader({
    required this.colors,
    required this.icon,
    required this.tint,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: tint),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 25),
          child: Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MerchantRow extends StatelessWidget {
  final AppColors colors;
  final AxioMerchantTag tag;

  const _MerchantRow({required this.colors, required this.tag});

  @override
  Widget build(BuildContext context) {
    final catColor = ExpenseCategories.getColor(tag.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              ExpenseCategories.getIcon(tag.category),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  context.l10n.categoryName(tag.category),
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              context.l10n.importTimesSeen(tag.count),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
