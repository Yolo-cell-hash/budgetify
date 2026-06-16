import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/monthly_recap.dart';
import '../providers/theme_provider.dart';
import '../services/recap_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/wrapped_card.dart';

/// Monthly "Wrapped": a privacy-safe, shareable recap of any month with at
/// least [MonthlyRecap.minDays] days of activity. Pick a month, then share the
/// card to WhatsApp / Instagram / anywhere via the system share sheet.
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

  late List<DateTime> _months;
  late DateTime _selected;
  MonthlyRecap? _recap;
  bool _loading = true;
  bool _sharing = false;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = List.generate(12, (i) => DateTime(now.year, now.month - i, 1));
    final init = widget.initialMonth;
    _selected = init == null ? _months.first : DateTime(init.year, init.month, 1);
    _load(_selected);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
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

  /// Capture the card as a PNG and return the temp file path.
  Future<File?> _captureCard() async {
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final period = DateFormat('yyyy-MM').format(_selected);
      final file = await File('${dir.path}/budgetify_wrapped_$period.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      return file;
    } catch (e) {
      return null;
    }
  }

  /// Share to a specific app by package name, or the generic share sheet.
  Future<void> _shareTo({String? targetPackage}) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _captureCard();
      if (file == null) throw Exception('Capture failed');
      final monthName = DateFormat('MMMM yyyy').format(_selected);

      if (targetPackage != null) {
        // Use share_plus with suggested app package
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text:
              'My $monthName on Budgetify ✨ — private, on-device money tracking.',
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text:
              'My $monthName on Budgetify ✨ — private, on-device money tracking.',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: 'Could not share the card', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recap = _recap;
    final eligible = recap?.isEligible ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Wrapped'),
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
    final monthFormat = DateFormat('MMM yyyy');
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
            onTap: () => _load(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : colors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? AppColors.gold : colors.border,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                isCurrent ? 'This Month' : monthFormat.format(m),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        children: [
          FadeSlideIn(
            order: 0,
            child: FittedBox(
              child: RepaintBoundary(
                key: _cardKey,
                child: WrappedCard(recap: recap),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Share section
          FadeSlideIn(
            order: 1,
            child: Column(
              children: [
                // Primary share button
                SizedBox(
                  width: double.infinity,
                  child: _ShareButton(
                    onPressed: _sharing ? null : () => _shareTo(),
                    isLoading: _sharing,
                    shimmerController: _shimmerController,
                  ),
                ),
                const SizedBox(height: 14),

                // WhatsApp & Instagram specific share buttons
                Row(
                  children: [
                    Expanded(
                      child: _PlatformShareButton(
                        icon: _whatsAppIcon(),
                        label: 'WhatsApp',
                        gradientColors: const [
                          Color(0xFF128C7E),
                          Color(0xFF25D366),
                        ],
                        onTap: _sharing
                            ? null
                            : () =>
                                _shareTo(targetPackage: 'com.whatsapp'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlatformShareButton(
                        icon: _instagramIcon(),
                        label: 'Instagram',
                        gradientColors: const [
                          Color(0xFFF58529),
                          Color(0xFFDD2A7B),
                          Color(0xFF8134AF),
                        ],
                        onTap: _sharing
                            ? null
                            : () => _shareTo(
                                targetPackage:
                                    'com.instagram.android'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          FadeSlideIn(
            order: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 15, color: colors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only percentages & names on the card — no amounts. Your finances stay private.',
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

  Widget _whatsAppIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text('💬', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _instagramIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text('📷', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildInsufficient(AppColors colors, MonthlyRecap? recap) {
    final now = DateTime.now();
    final isCurrent =
        _selected.year == now.year && _selected.month == now.month;
    final monthName = DateFormat('MMMM').format(_selected);
    final days = recap?.availableDays ?? 0;

    final message = isCurrent
        ? "$monthName is still warming up. A Wrapped needs at least "
            "${MonthlyRecap.minDays} days of activity — there ${days == 1 ? 'is' : 'are'} "
            "$days day${days == 1 ? '' : 's'} so far. Check back later in the month."
        : "Not enough data for $monthName — a Wrapped needs at least "
            "${MonthlyRecap.minDays} days of recorded activity in the month.";

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
              'Not enough data yet',
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
                      color: AppColors.gold,
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
  final AnimationController shimmerController;

  const _ShareButton({
    required this.onPressed,
    required this.isLoading,
    required this.shimmerController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: const [
                Color(0xFF3A3220),
                AppColors.gold,
                Color(0xFF3A3220),
              ],
              stops: [
                (shimmerController.value - 0.3).clamp(0.0, 1.0),
                shimmerController.value,
                (shimmerController.value + 0.3).clamp(0.0, 1.0),
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
              gradient: const LinearGradient(
                colors: AppColors.heroGradient,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Preparing…',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.ios_share_rounded,
                      color: AppColors.gold, size: 19),
                  const SizedBox(width: 10),
                  const Text(
                    'Share my Wrapped',
                    style: TextStyle(
                      color: Colors.white,
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

// ─── Platform-specific share buttons (WhatsApp / Instagram) ───────────

class _PlatformShareButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const _PlatformShareButton({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? colors.card : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gradient icon container
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
