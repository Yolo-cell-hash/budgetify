import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';

import '../models/achievement.dart';
import '../models/plus_offers.dart';
import '../models/plus_products.dart';
import '../providers/app_preferences.dart';
import '../providers/theme_provider.dart';
import '../screens/trophy_room_screen.dart' show gamiFormat;
import '../services/app_icon_service.dart';
import '../services/billing_service.dart';
import '../services/entitlement_service.dart';
import '../services/gamification_service.dart';
import 'app_dialog.dart';
import 'app_toast.dart';
import 'avatars.dart';
import 'badge_medallion.dart';
import 'royal_avatars.dart';
import 'royal_showcase.dart';

/// Edit the profile's avatar (emoji or procedural pixel) + accent + username.
/// Returns the edited [GamiProfile], or null if cancelled.
///
/// Royal avatars are gated two ways, and both live here. [unlockedRoyals] are
/// the ids the user already has — streak picks AND royals bought outright,
/// which is what `GamificationService.unlockedRoyalIds()` unions — and
/// [royalPicksAvailable] is how many still-locked royals a streak entitles
/// them to take for free right now. Spending a pick calls [onUnlockRoyal] so
/// the host can persist it; buying goes straight to [BillingService], which
/// records ownership itself. The currently-equipped royal (if any) is always
/// treated as unlocked, so nobody loses their face.
///
/// ELITE characters are gated too, on achievement badges rather than money.
/// [stats] is the snapshot every badge is evaluated against, so the sheet can
/// say both whether a character is open and how far off it still is. Pass null
/// only where stats genuinely aren't to hand — the section then reads as fully
/// locked, which is honest but joyless, so prefer passing them.
/// [legacyEliteSlots] are the elites the user was already wearing when the tier
/// was re-gated (`GamificationService.legacyEliteSlots()`); they stay open
/// whatever the badges say.
Future<GamiProfile?> showAvatarPicker(
  BuildContext context,
  GamiProfile initial, {
  Set<String> unlockedRoyals = const {},
  int royalPicksAvailable = 0,
  Future<void> Function(String royalId)? onUnlockRoyal,
  bool scrollToRoyalty = false,
  GamiStats? stats,
  Set<int> legacyEliteSlots = const {},
  DateTime Function()? nowSource,
}) {
  return showModalBottomSheet<GamiProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AvatarPickerSheet(
      initial: initial,
      unlockedRoyals: unlockedRoyals,
      royalPicksAvailable: royalPicksAvailable,
      onUnlockRoyal: onUnlockRoyal,
      scrollToRoyalty: scrollToRoyalty,
      stats: stats,
      legacyEliteSlots: legacyEliteSlots,
      nowSource: nowSource,
    ),
  );
}

/// After an avatar is saved, bring the Android launcher icon in step with the
/// equipped royal — only when the "match app icon" opt-in is on and the swap
/// would actually change the icon. Android applies alternate icons by toggling
/// launcher components, and launchers only pick the new artwork up reliably
/// once the app has been through a fresh start; so we ask first and, on
/// confirm, apply and RESTART. A no-op off-Android or when unchanged.
///
/// The restart used to be a plain close, leaving the user on their home screen
/// to reopen the app themselves — an errand handed out for a cosmetic change
/// they made two taps ago. [AppIconService.relaunch] brings it straight back
/// up instead; closing is only the fallback for when the platform can't.
///
/// Call this *after* the profile is persisted, so the restart can never lose
/// the equip.
Future<void> confirmRoyalAppIcon(
  BuildContext context,
  GamiProfile profile,
) async {
  if (!Platform.isAndroid) return;
  final enabled = context.read<AppPreferences>().royalAppIcon;
  final seed = int.tryParse(profile.avatarValue) ?? -1;
  if (!await AppIconService.willChange(equippedSeed: seed, enabled: enabled)) {
    return; // icon already matches — nothing to apply, no need to disturb.
  }
  if (!context.mounted) return;
  final confirmed = await showAppDialog<bool>(
    context,
    builder: (ctx) => AppDialog(
      icon: Icons.restart_alt_rounded,
      title: ctx.l10nRead.royalAppIconRestartTitle,
      subtitle: ctx.l10nRead.royalAppIconRestartBody,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10nRead.notNow),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10nRead.royalAppIconRestartConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await AppIconService.sync(equippedSeed: seed, enabled: enabled);
  // Icon swapped — take the fresh start that makes launchers show it, by
  // relaunching rather than closing. The user agreed and the profile is
  // already saved, so either path is safe.
  if (await AppIconService.relaunch()) return;
  await SystemNavigator.pop(); // platform couldn't relaunch — close instead
}

/// Whether the court sheet draws its Android-only "match app icon" row.
///
/// A seam, not a feature: that row exists only on Android, so every layout
/// measurement taken on a desktop test host was 53dp short of the tallest
/// sheet the app actually ships — which is precisely the configuration a
/// fits-on-one-screen guarantee has to be proved against.
@visibleForTesting
bool debugForceRoyalAppIconRow = false;

class _AvatarPickerSheet extends StatefulWidget {
  final GamiProfile initial;
  final Set<String> unlockedRoyals;
  final int royalPicksAvailable;
  final Future<void> Function(String royalId)? onUnlockRoyal;
  final bool scrollToRoyalty;

  /// The achievement snapshot the ELITE section is gated on. Null means "no
  /// stats to hand" — every elite reads as locked, with no progress to show.
  final GamiStats? stats;

  /// Elite sprite slots banked before the tier was re-gated — open regardless.
  final Set<int> legacyEliteSlots;

  /// Injectable clock. A royal's price depends on the calendar (offer
  /// windows), so a test must be able to pin the date — otherwise the same
  /// suite would quote a different price at Diwali than in July. Null in
  /// production.
  final DateTime Function()? nowSource;

  const _AvatarPickerSheet({
    required this.initial,
    this.unlockedRoyals = const {},
    this.royalPicksAvailable = 0,
    this.onUnlockRoyal,
    this.scrollToRoyalty = false,
    this.stats,
    this.legacyEliteSlots = const {},
    this.nowSource,
  });

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  // Royals the user may equip — only those unlocked with a streak pick.
  late final Set<String> _unlocked = {...widget.unlockedRoyals};

  /// Every achievement badge already earned. The ELITE section reads nothing
  /// else: a character is open exactly when its badge is in here.
  late final Set<String> _earnedBadges =
      widget.stats == null ? const <String>{} : earnedBadgeIds(widget.stats!);

  /// Elites banked before the gate (see `GamificationService.legacyEliteSlots`)
  /// plus, belt and braces, whatever the profile walked in wearing — the host
  /// records that on load, but a caller that skipped the service should still
  /// never grey out the user's own face.
  late final Set<int> _legacyElites = {
    ...widget.legacyEliteSlots,
    ?_initialEliteSlot(),
  };

  int? _initialEliteSlot() {
    if (widget.initial.avatarKind != 'pixel') return null;
    final seed = int.tryParse(widget.initial.avatarValue);
    return seed != null && eliteAvatarAt(seed) != null ? seed : null;
  }

  bool _eliteUnlocked(EliteAvatar e) =>
      _earnedBadges.contains(e.badgeId) ||
      _legacyElites.contains(e.spriteIndex);

  /// How many elites are open, for the section's own status line.
  int get _eliteUnlockedCount => kEliteAvatars.where(_eliteUnlocked).length;

  // The roster is pixel-only; a legacy emoji profile opens on its migration
  // sprite. A royal that isn't unlocked (e.g. one restored from a pre-gating
  // backup) can never be the equipped value — fall back to a basic avatar.
  late String _value = _sanitizedInitialValue();
  late bool _applyRoyalTheme = widget.initial.applyRoyalTheme;
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.username,
  );

  // Picks left to spend on still-locked royals this session.
  late int _picks = widget.royalPicksAvailable;

  /// The discount window running when the picker opened, or null at the
  /// everyday price. Read ONCE: a window flipping mid-session would swap the
  /// price under the user's finger. Fails to null on any error — quoting the
  /// base price and charging it is merely unexciting, while quoting a
  /// discount Play won't honour is a refund and a one-star review.
  late final PlusOffer? _offer = _readOffer();

  bool get _onOffer => _offer != null;

  /// Play's own prices for the royal catalogue, keyed by product id. Empty
  /// until the store answers — and whenever it can't — which is why every
  /// read falls back to the catalogue constant.
  Map<String, StorePrice> _royalPrices = const <String, StorePrice>{};

  /// True while a royal purchase flow is open, so a second tap can't ask the
  /// store for a second sheet.
  bool _buying = false;

  PlusOffer? _readOffer() {
    try {
      final now = widget.nowSource?.call();
      final svc = EntitlementService();
      return now == null ? svc.activeOffer : svc.offerAt(now);
    } catch (e) {
      debugPrint('AvatarPicker: offer window unreadable, using base price: $e');
      return null;
    }
  }

  String _sanitizedInitialValue() {
    final v = widget.initial.avatarKind == 'pixel'
        ? widget.initial.avatarValue
        : '${legacyEmojiSeed(widget.initial.avatarValue)}';
    final royal = royalAvatarAt(int.tryParse(v) ?? -1);
    if (royal != null && !_unlocked.contains(royal.id)) return '0';
    return v;
  }

  // Anchors the ROYALTY section so an "Unlock Now" deep-link can scroll to it.
  final GlobalKey _royaltyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadRoyalPrices();
    if (widget.scrollToRoyalty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Let the sheet finish presenting, then bring ROYALTY into view.
        await Future.delayed(const Duration(milliseconds: 320));
        final ctx = _royaltyKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          alignment: 0.05,
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  bool _isRoyalUnlocked(RoyalAvatar r) => _unlocked.contains(r.id);

  /// Spend a pick to unlock [r], then equip it. Persists via [onUnlockRoyal].
  Future<void> _unlockRoyal(RoyalAvatar r) async {
    if (_picks <= 0 || _isRoyalUnlocked(r)) return;
    setState(() {
      _unlocked.add(r.id);
      _picks -= 1;
      _value = '${r.spriteIndex}';
    });
    await widget.onUnlockRoyal?.call(r.id);
  }

  // ── What a royal costs ─────────────────────────────────────────────────

  /// Replace the previewed constant with what Play will actually charge.
  ///
  /// [kRoyalAvatarPriceInr] is honest only while it matches the Play Console;
  /// asking the store makes it a fallback rather than a claim. It also
  /// localizes for free — Play returns the price already formatted for the
  /// buyer's country and tax rules, which no hardcoded rupee string can do.
  Future<void> _loadRoyalPrices() async {
    final prices = await BillingService()
        .prices(kRoyalAvatars.map((r) => royalProductId(r.id)));
    if (!mounted || prices.isEmpty) return;
    setState(() => _royalPrices = prices);
  }

  static final NumberFormat _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  /// What [r] costs right now — Play's own price once the store has answered,
  /// the catalogue constant until then. Play charges what the Console says,
  /// offer window or not, so its answer wins outright.
  String _royalPrice(RoyalAvatar r) =>
      _royalPrices[royalProductId(r.id)]?.formatted ??
      _inr.format(royalAvatarPriceInr(onOffer: _onOffer));

  /// Whether the struck-through everyday price is a TRUE claim right now —
  /// i.e. Play is really about to charge less than [kRoyalAvatarPriceInr].
  ///
  /// An offer window is our calendar, not Play's. With no matching Console
  /// discount Play charges the everyday price, and the strikethrough would
  /// cross out a number identical to the one beside it — so the "was" price
  /// only appears once the store's own answer says the reduction is real.
  bool _royalDiscountIsReal(RoyalAvatar r) {
    if (!_onOffer) return false;
    final live = _royalPrices[royalProductId(r.id)];
    if (live == null) return true;
    return live.amount < kRoyalAvatarPriceInr;
  }

  /// Buy [r] outright, then equip it and close the court sheet.
  ///
  /// Ownership is persisted by [BillingService] itself (via
  /// `EntitlementService.registerRoyalPurchase`), not by Save — so backing out
  /// of the picker afterwards can never lose a royal somebody paid for. The
  /// equip still rides on Save, exactly like a pick-unlocked royal.
  Future<void> _buyRoyal(
    BuildContext sheetCtx,
    RoyalAvatar r,
    StateSetter setSheetState,
  ) async {
    if (_buying || _isRoyalUnlocked(r)) return;
    setState(() => _buying = true);
    setSheetState(() {});
    final l10n = context.l10nRead;

    final outcome = await BillingService().purchase(royalProductId(r.id));
    if (!mounted) return;
    final bought = outcome == BillingOutcome.success;
    setState(() {
      _buying = false;
      if (bought) {
        _unlocked.add(r.id);
        _value = '${r.spriteIndex}';
      }
    });
    if (sheetCtx.mounted) {
      // Close on success (the picker behind now shows him equipped); on any
      // other verdict leave the sheet up, just no longer busy.
      if (bought) {
        Navigator.pop(sheetCtx);
      } else {
        setSheetState(() {});
      }
    }
    switch (outcome) {
      case BillingOutcome.success:
        showAppToast(
          context,
          message: l10n.royalPurchasedToast(l10n.royalAvatarName(r.id)),
          type: AppToastType.success,
        );
      case BillingOutcome.unavailable:
        showAppToast(
          context,
          message: l10n.plusStoreUnavailable,
          type: AppToastType.info,
        );
      case BillingOutcome.cancelled:
      case BillingOutcome.pending:
      case BillingOutcome.error:
        break; // the store's own sheet already told the story
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    // Just hand the edited profile back; the caller persists it and then — if
    // the "match app icon" opt-in wants a different launcher icon — asks before
    // applying it (the swap closes the app). See [confirmRoyalAppIcon].
    Navigator.pop(
      context,
      widget.initial.copyWith(
        username: _name.text.trim(),
        avatarKind: 'pixel',
        avatarValue: _value,
        applyRoyalTheme: _applyRoyalTheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              // Keyed by the selection so equipping a royal replays its
              // spawn flourish in the preview.
              child: AvatarView(
                key: ValueKey(_value),
                kind: 'pixel',
                value: _value,
                size: 88,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: context.l10n.usernameLabel,
                hintText: context.l10n.pickAName,
              ),
            ),
            const SizedBox(height: 8),
            _sectionLabel(colors, context.l10n.pixelAvatarLabel),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final seed in kFreePixelSeeds)
                  _option(colors, '$seed', '$seed' == _value),
              ],
            ),
            // Elite characters: showpiece art, each behind its own badge.
            const SizedBox(height: 16),
            Row(
              children: [
                // Flexible both ways: at a large accessibility text scale on a
                // narrow phone, a fixed label plus a fixed score overran the
                // row. Neither string's width is ours to predict — both are
                // translated into six languages.
                Flexible(
                  child: _sectionLabel(colors, context.l10n.eliteAvatarsLabel),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 14,
                  color: colors.brandAccent,
                ),
                const Spacer(),
                const SizedBox(width: 6),
                // The scoreboard. A row of ten locked circles reads as "these
                // are not for you"; "3 / 10 earned" reads as a score with more
                // of it to get — the whole difference between a wall and a
                // ladder is knowing where you are on it.
                Flexible(
                  child: Text(
                    context.l10n.eliteEarnedCount(
                      _eliteUnlockedCount,
                      kEliteAvatars.length,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: _eliteUnlockedCount == kEliteAvatars.length
                          ? colors.brandAccent
                          : colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.eliteAvatarsDesc,
              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in kEliteAvatars) _eliteOption(colors, e),
              ],
            ),
            // Royalty: the court above elite — living avatars with their
            // own aura, backdrop and profile-card theme.
            const SizedBox(height: 18),
            Row(
              key: _royaltyKey,
              children: [
                _sectionLabel(colors, context.l10n.royalAvatarsLabel),
                const SizedBox(width: 6),
                const Text('👑', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.royalAvatarsDesc,
              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
            ),
            const SizedBox(height: 10),
            _royalStatusLine(colors),
            const SizedBox(height: 12),
            // Two showpiece tiles per row — the court is too large for one.
            LayoutBuilder(
              builder: (ctx, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final r in kRoyalAvatars)
                      SizedBox(
                        width: tileWidth,
                        child: _royalOption(colors, r),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(context.l10n.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(AppColors colors, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w700,
      color: colors.textSecondary,
    ),
  );

  /// The ROYALTY unlock status: a gold call-to-action when picks are waiting,
  /// otherwise a calm line naming both routes in — a streak, or a purchase.
  /// Hidden once the whole court is unlocked (nothing left to say).
  Widget _royalStatusLine(AppColors colors) {
    final allUnlocked = kRoyalAvatars.every(_isRoyalUnlocked);
    if (allUnlocked) return const SizedBox.shrink();
    if (_picks > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.brandAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.brandAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_open_rounded, size: 14, color: colors.brandAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.royalPicksAvailable(_picks),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: colors.brandAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      context.l10n.royalLockedHint,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.35,
        color: colors.textTertiary,
      ),
    );
  }

  Widget _option(AppColors colors, String value, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _value = value),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.brandAccent : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: AvatarView(kind: 'pixel', value: value, size: 46, ring: false),
      ),
    );
  }

  /// Where the court stands on the theme the user is actually in.
  ///
  /// This used to be a correction — every royal dressed one mode only, so the
  /// row's job was to tell you that you were in the wrong one. Now that the
  /// court follows both primaries it confirms the dress is live and offers
  /// the *other* mode, so trying a royal both ways is one tap either
  /// direction. A reward theme is the one place the dress still stands
  /// aside (each is hand-tuned), so there the row keeps its original job and
  /// offers the primary nearest the brightness the user already reads in.
  Widget _modeSwitchRow(BuildContext ctx, RoyalAvatar r, Color accent) {
    final theme = ctx.watch<ThemeProvider>();
    final onLight = theme.variant == AppThemeVariant.light;
    final onPrimary = onLight || theme.variant == AppThemeVariant.dark;

    Widget switchButton(bool toLight) => Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: TextButton.icon(
        onPressed: () => theme.setVariant(
          toLight ? AppThemeVariant.light : AppThemeVariant.dark,
        ),
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(
          toLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 16,
        ),
        label: Text(
          ctx.l10n.royalSwitchMode(toLight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
    );

    if (!onPrimary) {
      // A reward theme: the court steps aside here. Offer the primary that
      // matches the brightness they're already reading in.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: switchButton(Theme.of(ctx).brightness == Brightness.light),
      );
    }
    // Confirmation and offer on ONE line. Stacked they ran 62dp inside a
    // settings card that has three other rows to fit; side by side they say
    // the same two things in 38.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // Both halves are Flexible and both can ellipsize. Neither string is
      // ours to size — they are translated into six languages, and the German
      // -length case of an Indic script will overrun any fixed split.
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            flex: 5,
            child: Text(
              ctx.l10n.royalCourtLive(onLight),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.25,
                color: AppColors.of(ctx).textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(flex: 6, child: switchButton(!onLight)),
        ],
      ),
    );
  }

  /// The royal's court sheet: living avatar, lore, the both-modes promise,
  /// the per-royal app-wide theme toggle, and the Equip action.
  Future<void> _showRoyalSheet(RoyalAvatar r) async {
    final value = '${r.spriteIndex}';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // The court sheet is a product page, not a menu: capped at the default
      // 9/16 of the screen it showed 39% of itself and hid the price. Material
      // is explicit that a sheet should take the height its content needs, and
      // the body below is built to stop growing once it has it.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      // A modal CAPTURES its Theme at push time (InheritedTheme.capture), so
      // the sheet would keep painting in whichever mode it opened in while
      // the app behind it changed — and the row inside it exists precisely to
      // change that mode. ThemeProvider is not captured: it resolves live
      // through the tree, so watching it and re-installing the active theme
      // over the sheet is what lets "See it in the Dark theme" actually show
      // you the sheet in dark.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Theme(
          data: ctx.watch<ThemeProvider>().activeTheme,
          // Nested Builder so AppColors.of / Theme.of below resolve through
          // the theme just installed, not the captured one above it.
          child: Builder(
            builder: (ctx) => _royalSheetBody(ctx, r, value, setSheetState),
          ),
        ),
      ),
    );
  }

  /// The court sheet's contents, under the live app theme (see the Theme wrap
  /// in [_showRoyalSheet]). [setSheetState] rebuilds the sheet for the toggles
  /// that live on it.
  ///
  /// Three bands, and the split is the whole point: an identity HEADER, a
  /// scrolling MIDDLE, and a footer that never scrolls away. Everything used to
  /// be one long column inside a half-height sheet — 1204dp of content in a
  /// 470dp window on an ordinary phone — so the price and the button that
  /// charges it were both two scrolls below the fold. Pinning the decision to
  /// the bottom is what every commerce sheet does, and it is the only structure
  /// that stays honest at a text scale or a screen size we did not measure:
  /// whatever else has to give, the reader can always see what this costs and
  /// how to say yes or no.
  Widget _royalSheetBody(
    BuildContext ctx,
    RoyalAvatar r,
    String value,
    StateSetter setSheetState,
  ) {
    final colors = AppColors.of(ctx);
    // A royal's bright accent (gold / lavender) is legible on a dark
    // surface but washes out on the light picker; use the deep,
    // ink-legible shade whenever the surface is light so names and
    // borders stay readable.
    final onLightSurface = Theme.of(ctx).brightness == Brightness.light;
    final accent = onLightSurface ? r.theme.accentDeep : r.theme.accent;
    // Label ink for a filled button in [accent]: white on the deep
    // shade, near-black on the bright one. Keyed to the surface the
    // sheet is on, not to the royal — every court dresses both modes.
    final onAccent = onLightSurface ? Colors.white : const Color(0xFF15171E);
    final equipped = _value == value;
    final unlocked = _isRoyalUnlocked(r);
    final unlockable = !unlocked && _picks > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      // Flutter 3.44 asserts if a ListTile's nearest Material ancestor is
      // further away than a DecoratedBox with a background — the tile
      // would paint its ink splashes behind this sheet's own fill. A
      // transparent Material INSIDE the decoration gives the switches
      // below somewhere to splash without changing how anything looks.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            _royalHeader(
              ctx,
              r,
              value,
              colors,
              accent,
              showDualMode: !unlocked,
            ),
            const SizedBox(height: 12),
            // The scrolling band. Loose, so the sheet is content-height when
            // everything fits and only starts scrolling when it genuinely
            // cannot — the footer below keeps its place either way.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoyalShowcase(royal: r),
                    if (unlocked) ...[
                      const SizedBox(height: 10),
                      _royalSettings(ctx, r, colors, accent, setSheetState),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _royalFooter(
              ctx,
              r,
              colors,
              accent,
              onAccent,
              unlocked: unlocked,
              unlockable: unlockable,
              equipped: equipped,
              value: value,
              setSheetState: setSheetState,
            ),
          ],
        ),
      ),
    );
  }

  /// Who this is: the face, the name, the lore and the both-modes promise, on
  /// one row instead of four stacked centre-aligned blocks.
  ///
  /// The circle used to be 92dp and alone above the name. It is the same
  /// character the showcase below draws twice over, so at that size it was
  /// spending 170dp of a 470dp window to say something the next widget says
  /// better. Shrunk and set beside the name it still does its real job —
  /// telling you what lands on your profile — for a third of the room.
  Widget _royalHeader(
    BuildContext ctx,
    RoyalAvatar r,
    String value,
    AppColors colors,
    Color accent, {
    required bool showDualMode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarView(kind: 'pixel', value: value, size: 54, ring: false),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctx.l10n.royalAvatarName(r.id),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: accent,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                ctx.l10n.royalAvatarLore(r.id),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.32,
                  color: colors.textSecondary,
                ),
              ),
              // The court dresses BOTH primaries, so this promises reach
              // rather than naming one mode. A hairline row now rather than a
              // filled pill: the sheet already carries an accent border, a
              // gold name and an accent CTA, and a fourth accent block was
              // one flourish past premium.
              //
              // Sales copy, so it is dropped for an owner: the settings card
              // below carries the LIVE version of the same fact ("its court is
              // live on your Dark theme"), and saying it twice cost 36dp on
              // the one sheet that has none to spare.
              if (showDualMode) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(Icons.brightness_6_rounded, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ctx.l10n.royalDualModeNote,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The per-royal controls, for a royal the user already owns.
  ///
  /// Grouped into one bordered card with compact rows. As SwitchListTiles they
  /// ran 58dp, 150dp and 58dp — the middle one alone was a third of the
  /// visible sheet — because each carried a full explanatory paragraph. The
  /// explanations stay, at caption size, under titles that are already almost
  /// self-describing.
  Widget _royalSettings(
    BuildContext ctx,
    RoyalAvatar r,
    AppColors colors,
    Color accent,
    StateSetter setSheetState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.cardAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // "Apply app-wide <court> theme" — the royal's own wording.
          _settingRow(
            colors: colors,
            accent: accent,
            title: ctx.l10n.royalThemeToggle(r.id),
            value: _applyRoyalTheme,
            onChanged: (v) {
              setState(() => _applyRoyalTheme = v);
              setSheetState(() {});
            },
          ),
          _settingDivider(colors),
          // Full-body theatrics (off by default): the royal roaming, peeking
          // and attacking the screen. Global and persisted immediately via
          // AppPreferences — not part of this profile, so Save/Cancel doesn't
          // touch it. The circle avatar keeps blinking and waving either way.
          _settingRow(
            colors: colors,
            accent: accent,
            title: ctx.l10n.royalCustomAnimationsTitle,
            subtitle: ctx.l10n.royalCustomAnimationsDesc,
            value: ctx.watch<AppPreferences>().royalCustomAnimations,
            onChanged: (v) {
              ctx.read<AppPreferences>().setRoyalCustomAnimations(v);
              setSheetState(() {});
            },
          ),
          // Opt-in: match the Android launcher icon to this royal's gem. The
          // switch only records the preference; the icon is swapped (after a
          // confirm, since it closes the app) when the avatar is saved.
          //
          // A previous pass reconciled the icon the moment the switch moved,
          // on the theory that the swap is silent because the native side
          // passes DONT_KILL_APP. It is not: disabling the launcher component
          // the running task is attached to tears the task down anyway on real
          // devices, so flicking the switch force-closed the app — before any
          // confirmation, and for an avatar the user had not chosen to keep
          // yet. There is no such thing as a quiet icon swap, which is why
          // every one of them now sits behind the confirm-and-relaunch path.
          if (Platform.isAndroid || debugForceRoyalAppIconRow) ...[
            _settingDivider(colors),
            _settingRow(
              colors: colors,
              accent: accent,
              title: ctx.l10n.royalAppIconTitle,
              value: ctx.watch<AppPreferences>().royalAppIcon,
              onChanged: (v) {
                ctx.read<AppPreferences>().setRoyalAppIcon(v);
                setSheetState(() {});
              },
            ),
          ],
          _settingDivider(colors),
          // Where the court stands on the active theme, and a one-tap hop to
          // see it in the other mode.
          _modeSwitchRow(ctx, r, accent),
        ],
      ),
    );
  }

  Widget _settingDivider(AppColors colors) =>
      Divider(height: 1, thickness: 1, color: colors.border);

  /// One compact switch row: title, an optional caption, and the switch.
  Widget _settingRow({
    required AppColors colors,
    required Color accent,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return Padding(
      // 4, not 8: four rows of a switch, a title and a caption is the tallest
      // thing on the owned sheet, and every dp of row padding is multiplied by
      // four. The rows still clear 48dp, so nothing loses a tap target.
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    // Three, not two: at two the one caption that has real
                    // work to do — saying WHERE the animations happen — was
                    // cut off mid-sentence, and the sheet has the room.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Dense so the row is set by its text, not by the switch's own
          // 48dp tap slab.
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  /// The band that never scrolls: what this costs (or what you own) and the
  /// one action that follows from it.
  Widget _royalFooter(
    BuildContext ctx,
    RoyalAvatar r,
    AppColors colors,
    Color accent,
    Color onAccent, {
    required bool unlocked,
    required bool unlockable,
    required bool equipped,
    required String value,
    required StateSetter setSheetState,
  }) {
    if (unlocked) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: equipped
              ? null
              : () {
                  setState(() => _value = value);
                  Navigator.pop(ctx);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            disabledBackgroundColor: accent.withValues(alpha: 0.35),
          ),
          icon: Icon(
            equipped ? Icons.check_rounded : Icons.workspace_premium_rounded,
            size: 18,
          ),
          label: Text(equipped ? ctx.l10n.equippedRoyal : ctx.l10n.equipRoyal),
        ),
      );
    }

    if (unlockable) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await _unlockRoyal(r);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (mounted) {
              showAppToast(
                context,
                message: context.l10nRead.royalUnlockedToast(
                  context.l10nRead.royalAvatarName(r.id),
                ),
                type: AppToastType.success,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
          ),
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: Text(ctx.l10n.unlockRoyalCta),
        ),
      );
    }

    // Locked with no pick to spend, so this royal is bought. The price sits on
    // its own line and AGAIN inside the button, which is not redundancy: the
    // pick path and the buy path are the same shape, and a button reading
    // "Unlock & equip" while it is about to charge money hides the charge. The
    // free route stays underneath, and it is the reason this reads as an offer
    // rather than a toll gate.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _royalPrice(r),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            // The everyday price, struck through — drawn only when Play
            // confirms it is really about to charge less.
            if (_royalDiscountIsReal(r)) ...[
              const SizedBox(width: 8),
              Text(
                _inr.format(kRoyalAvatarPriceInr),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textTertiary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: colors.textTertiary,
                  decorationThickness: 2.2,
                ),
              ),
            ],
            const Spacer(),
            Text(
              ctx.l10n.royalPriceCaption,
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _buying ? null : () => _buyRoyal(ctx, r, setSheetState),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: onAccent,
              disabledBackgroundColor: accent.withValues(alpha: 0.35),
            ),
            icon: _buying
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(onAccent),
                    ),
                  )
                : const Icon(Icons.lock_open_rounded, size: 18),
            label: Text(
              ctx.l10n.buyRoyalCta(_royalPrice(r)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: colors.textTertiary,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                ctx.l10n.royalLockedSheetNote,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A royal character tile — a living avatar with its court name and a status
  /// pill beneath. Every tile is the SAME height (avatar + name + pill), so the
  /// grid stays even regardless of lock state. The art is always fully visible;
  /// a locked royal is dimmed a touch and carries a small lock badge in the
  /// corner (never over the face). Tapping opens the royal's court sheet.
  Widget _royalOption(AppColors colors, RoyalAvatar r) {
    final value = '${r.spriteIndex}';
    final unlocked = _isRoyalUnlocked(r);
    final equipped = unlocked && _value == value;
    final unlockable = !unlocked && _picks > 0;
    // Locked with no pick waiting: still fully visible, and now carrying its
    // price rather than a promise.
    final forSale = !unlocked && !unlockable;
    // The bright accent tints the tile fill; text + border use the deep
    // shade on a light surface so the selected name never sits gold-on-
    // yellow (illegible in light mode; fine on the dark tile).
    final accent = r.theme.accent;
    final ink = Theme.of(context).brightness == Brightness.light
        ? r.theme.accentDeep
        : r.theme.accent;
    final borderColor = equipped
        ? ink
        : unlockable
        ? colors.brandAccent.withValues(alpha: 0.6)
        : forSale
        ? colors.border
        : ink.withValues(alpha: 0.35);
    return GestureDetector(
      onTap: () => _showRoyalSheet(r),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              (forSale ? colors.textTertiary : accent).withValues(
                alpha: equipped ? 0.16 : 0.07,
              ),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: borderColor, width: equipped ? 2 : 1),
          boxShadow: equipped
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The living royal, always visible — locked ones just dimmed.
                  Opacity(
                    opacity: forSale ? 0.82 : 1,
                    child: ClipOval(
                      child: AvatarView(
                        kind: 'pixel',
                        value: value,
                        size: 60,
                        ring: false,
                        spawnRoyals: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.royalAvatarName(r.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: equipped
                          ? ink
                          : forSale
                          ? colors.textTertiary
                          : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _royalTilePill(
                    colors: colors,
                    equipped: equipped,
                    unlocked: unlocked,
                    unlockable: unlockable,
                    price: _royalPrice(r),
                    accent: ink,
                  ),
                ],
              ),
            ),
            // A subtle corner lock — signals "locked" without hiding the face.
            if (forSale)
              Positioned(top: 8, right: 8, child: _cornerLock(colors)),
          ],
        ),
      ),
    );
  }

  /// A small lock badge for the top-right corner of a locked royal tile.
  Widget _cornerLock(AppColors colors) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: colors.surface.withValues(alpha: 0.92),
      shape: BoxShape.circle,
      border: Border.all(color: colors.border),
    ),
    child: Icon(Icons.lock_rounded, size: 10, color: colors.textSecondary),
  );

  /// The status pill under every royal tile — present in all states so the
  /// tiles share one height: Equipped / Tap to equip / Unlock / the price.
  ///
  /// A pick beats money: while one is waiting the pill offers the free unlock
  /// and says nothing about cost, because for this user there isn't one.
  Widget _royalTilePill({
    required AppColors colors,
    required bool equipped,
    required bool unlocked,
    required bool unlockable,
    required String price,
    required Color accent,
  }) {
    final (IconData? icon, String label, Color fg) = equipped
        ? (Icons.check_circle_rounded, context.l10n.equippedRoyal, accent)
        : unlocked
        ? (null, context.l10n.royalTapToEquip, colors.textSecondary)
        : unlockable
        ? (
            Icons.lock_open_rounded,
            context.l10n.royalUnlockable,
            colors.brandAccent,
          )
        : (null, price, colors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// An elite tile. Earned ones equip on tap; locked ones are dimmed under a
  /// lock and open [_showEliteSheet], which names the badge and shows how far
  /// off it is.
  ///
  /// The art stays VISIBLE behind the dim rather than becoming a silhouette. A
  /// locked reward nobody can see is a reward nobody can want, and wanting it
  /// is the entire mechanism.
  Widget _eliteOption(AppColors colors, EliteAvatar e) {
    final value = '${e.spriteIndex}';
    final selected = _value == value;
    final unlocked = _eliteUnlocked(e);
    return GestureDetector(
      onTap: () {
        if (unlocked) {
          setState(() => _value = value);
        } else {
          _showEliteSheet(e);
        }
      },
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colors.brandAccent : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Opacity(
                    opacity: unlocked ? 1 : 0.32,
                    child: AvatarView(
                      kind: 'pixel',
                      value: value,
                      size: 46,
                      ring: false,
                    ),
                  ),
                ),
                if (!unlocked)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.cardAlt,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 11,
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.eliteAvatarName(e.id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: unlocked ? colors.textSecondary : colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The locked elite's sheet: the art being held back, the badge that opens
  /// it, and live progress toward that badge.
  ///
  /// A toast was the old answer and it was the wrong shape — one line, gone in
  /// three seconds, no sense of distance. What turns a lock into a goal is
  /// seeing how close you already are, so the medallion, the requirement and
  /// the bar all sit on one surface the user can stay with.
  Future<void> _showEliteSheet(EliteAvatar e) async {
    final badge = badgeById(e.badgeId);
    // Roster/catalog drift: say nothing rather than open an empty sheet. The
    // avatars suite asserts every elite badge resolves, so this is unreachable
    // in a shipped build.
    if (badge == null) return;
    final group = badge.group;
    final tier = group.tiers[badge.tierIndex];
    final progress =
        widget.stats == null ? null : evaluateGroup(group, widget.stats!);
    // Progress toward THIS tier, not the group's next unearned one: someone
    // already past tier 2 is all the way to a tier-1 elite, and a bar that
    // restarted at every rung would understate what they have done.
    final value = progress?.value ?? 0;
    final toward = (value / tier.threshold.toDouble()).clamp(0.0, 1.0);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // The art, the medallion, two paragraphs, a bar and a button outgrow the
      // default 9/16-of-screen cap on a short phone (and at any large text
      // scale), which puts Close below a fold the user cannot see to scroll.
      isScrollControlled: true,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: colors.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                // The prize and the price side by side: the character being
                // withheld, and the medal that releases it.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: 0.4,
                      child: AvatarView(
                        kind: 'pixel',
                        value: '${e.spriteIndex}',
                        size: 68,
                        ring: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.lock_rounded,
                        size: 18, color: colors.textTertiary),
                    const SizedBox(width: 12),
                    BadgeMedallion(
                      rarity: tier.rarity,
                      emblem: group.emblem,
                      earned: false,
                      size: 68,
                      animate: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  ctx.l10n.eliteAvatarName(e.id),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ctx.l10n.eliteAvatarLock(
                    ctx.l10n.achievementName(group.id),
                    ctx.l10n.tierBadgeLabel(tier.label),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ctx.l10n.achievementBlurb(group.id),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: colors.textTertiary,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: toward,
                      minHeight: 7,
                      backgroundColor: colors.cardAlt,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.brandAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ctx.l10n.eliteAvatarProgress(
                      gamiFormat(value, group.unit),
                      gamiFormat(tier.threshold, group.unit),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(ctx.l10n.commonClose),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
