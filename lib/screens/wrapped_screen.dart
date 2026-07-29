import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/monthly_recap.dart';
import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import '../services/recap_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/royal_avatars.dart';
import '../widgets/wrapped_card.dart';

/// Monthly "Wrapped": a privacy-safe, shareable recap of any month with at
/// least [MonthlyRecap.minDays] days of activity. Pick a month, then share the
/// card as a crisp still image to WhatsApp / Instagram / anywhere via the
/// system share sheet.
///
/// There was an "animated share" alongside it, dropped in v1.48.0. It exported
/// a GIF, which Instagram flattens to a still image and whose 256-colour
/// palette left WhatsApp re-encoding a banded source. Neither is fixable in a
/// GIF, and the only format both platforms animate is video — not worth a
/// platform encoder for one card, so the still is now the whole story.
/// The card itself is still alive on screen; only the export is static.
class WrappedScreen extends StatefulWidget {
  /// Month to open on first (defaults to the current month).
  final DateTime? initialMonth;

  const WrappedScreen({super.key, this.initialMonth});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen>
    with SingleTickerProviderStateMixin {
  final RecapService _service = RecapService();
  final GlobalKey _cardKey = GlobalKey();

  /// One period of the card's motion, driving every loop effect on it.
  static const Duration _loopPeriod = Duration(milliseconds: 2400);

  late List<DateTime> _months;
  late DateTime _selected;
  MonthlyRecap? _recap;
  RoyalAvatar? _royal;
  bool _loading = true;
  bool _sharing = false;
  bool _showAmounts = false; // reveal actual ₹ figures on the card

  /// Drives every loop effect on the card (sparks, border sheen, shimmer,
  /// peak pulse, royal seal) and the share button's own shimmer.
  late AnimationController _loop;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = List.generate(12, (i) => DateTime(now.year, now.month - i, 1));
    final init = widget.initialMonth;
    _selected = init == null ? _months.first : DateTime(init.year, init.month, 1);
    _load(_selected);
    _loadRoyal();

    _loop = AnimationController(vsync: this, duration: _loopPeriod)..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Future<void> _load(DateTime month) async {
    setState(() {
      _selected = month;
      _loading = true;
    });
    final recap = await _service.compute(month);
    if (!mounted) return;
    setState(() {
      _recap = recap;
      _loading = false;
    });
  }

  /// The equipped royal (if any) signs the card with its living seal.
  /// [GamificationService.loadProfile] already enforces the unlock gating.
  Future<void> _loadRoyal() async {
    final profile = await GamificationService().loadProfile();
    if (!mounted) return;
    setState(() {
      _royal = profile.avatarKind == 'pixel'
          ? royalAvatarAt(int.tryParse(profile.avatarValue) ?? -1)
          : null;
    });
  }

  RenderRepaintBoundary? get _boundary =>
      _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

  /// Capture the card as a PNG and return the temp file path.
  Future<File?> _capturePng() async {
    try {
      final image = await _boundary!.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = await getTemporaryDirectory();
      final period = DateFormat('yyyy-MM').format(_selected);
      return await File('${dir.path}/budgetify_wrapped_$period.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  /// Capture the card and hand it to the system share sheet (which already
  /// lists WhatsApp, Instagram, and everything else).
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final l10n = context.l10nRead;
    try {
      final file = await _capturePng();
      if (file == null) throw Exception('Capture failed');
      final monthName = l10n.monthYear(_selected);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: l10n.wrappedShareText(monthName),
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: l10n.couldNotShareCard, type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Toggle revealing actual amounts. Turning it ON first asks for
  /// confirmation via a themed dialog, since amounts will then appear on the
  /// card (and on anything shared).
  Future<void> _toggleAmounts(bool reveal) async {
    if (!reveal) {
      setState(() => _showAmounts = false);
      return;
    }
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.visibility_outlined,
        title: context.l10nRead.showActualAmountsTitle,
        subtitle: context.l10nRead.showAmountsDesc,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10nRead.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10nRead.showAmounts),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => _showAmounts = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recap = _recap;
    final eligible = recap?.isEligible ?? false;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.monthlyWrappedTitle,
            icon: Icons.auto_awesome_rounded),
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _monthSelector(colors),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : eligible
                      ? _buildEligible(recap!)
                      : _buildInsufficient(colors, recap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthSelector(AppColors colors) {
    final now = DateTime.now();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _months.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = _months[i];
          final selected =
              m.year == _selected.year && m.month == _selected.month;
          final isCurrent = m.year == now.year && m.month == now.month;
          return GestureDetector(
            // Month switches are parked while a share capture is running so
            // the frames all come from one recap.
            onTap: _sharing ? null : () => _load(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colors.brandAccent : colors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? colors.brandAccent : colors.border,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colors.brandAccent.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                isCurrent ? context.l10n.thisMonth : context.l10n.monthYear(m),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? const Color(0xFF15110A) : colors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEligible(MonthlyRecap recap) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        children: [
          // Reveal-amounts toggle sitting above the card
          FadeSlideIn(order: 0, child: _amountsToggle(colors)),
          const SizedBox(height: 14),

          FadeSlideIn(
            order: 1,
            child: FittedBox(
              child: RepaintBoundary(
                key: _cardKey,
                child: WrappedCard(
                  // Keyed per month so the entrance animations replay when
                  // the user hops between months.
                  key: ValueKey(_selected),
                  recap: recap,
                  showAmounts: _showAmounts,
                  loop: _loop,
                  royal: _royal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sharing the card is the whole point of the screen, so it's the
          // one marquee action. The system sheet offers WhatsApp, Instagram
          // and the rest.
          FadeSlideIn(
            order: 2,
            child: SizedBox(
              width: double.infinity,
              child: _ShareButton(
                onPressed: _sharing ? null : _share,
                isLoading: _sharing,
                label: l10n.shareMyWrapped,
                loadingLabel: l10n.preparing,
                icon: Icons.ios_share_rounded,
                shimmer: _loop,
              ),
            ),
          ),

          const SizedBox(height: 8),

          FadeSlideIn(
            order: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showAmounts
                      ? colors.brandAccent.withValues(alpha: 0.4)
                      : colors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                      _showAmounts
                          ? Icons.warning_amber_rounded
                          : Icons.lock_outline,
                      size: 15,
                      color: _showAmounts
                          ? colors.brandAccent
                          : colors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showAmounts
                          ? l10n.wrappedAmountsOnNote
                          : l10n.wrappedPrivacyNote,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pill toggle that switches the card between percentages and real amounts.
  Widget _amountsToggle(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            _showAmounts ? Icons.visibility : Icons.visibility_off_outlined,
            size: 17,
            color: _showAmounts ? colors.brandAccent : colors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.showActualAmounts,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          Switch(
            value: _showAmounts,
            onChanged: _sharing ? null : _toggleAmounts,
            activeTrackColor: colors.brandAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficient(AppColors colors, MonthlyRecap? recap) {
    final now = DateTime.now();
    final isCurrent =
        _selected.year == now.year && _selected.month == now.month;
    final monthName = context.l10n.monthName(_selected.month);
    final days = recap?.availableDays ?? 0;

    final message = isCurrent
        ? context.l10n.wrappedWarmingUp(monthName, MonthlyRecap.minDays, days)
        : context.l10n.wrappedNotEnoughData(monthName, MonthlyRecap.minDays);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.cardAlt,
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.auto_awesome_outlined,
                  size: 36, color: colors.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.notEnoughDataYet,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
            if (isCurrent && days > 0) ...[
              const SizedBox(height: 20),
              // Progress indicator toward minDays
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    AnimatedProgressBar(
                      value: days / MonthlyRecap.minDays,
                      color: colors.brandAccent,
                      backgroundColor: colors.border,
                      height: 5,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$days / ${MonthlyRecap.minDays} days',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Custom share button with shimmer animation ───────────────────────

class _ShareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final String loadingLabel;
  final IconData icon;
  final Animation<double> shimmer;

  const _ShareButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
    required this.loadingLabel,
    required this.icon,
    required this.shimmer,
  });

  @override
  Widget build(BuildContext context) {
    final hero = HeroStyle.of(context);
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                hero.accent.withValues(alpha: 0.25),
                hero.accent,
                hero.accent.withValues(alpha: 0.25),
              ],
              stops: [
                (shimmer.value - 0.3).clamp(0.0, 1.0),
                shimmer.value,
                (shimmer.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: hero.gradientColors),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: hero.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loadingLabel,
                    style: TextStyle(
                      color: hero.mutedForeground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Icon(icon, color: hero.accent, size: 19),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: hero.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
