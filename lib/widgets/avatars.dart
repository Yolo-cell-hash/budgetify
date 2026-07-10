import 'package:flutter/material.dart';

import 'royal_avatars.dart';

/// Premium accent gradients used for emoji avatars and as the profile's theme.
/// Index is persisted in the profile, so keep this list append-only.
const List<List<Color>> kAvatarAccents = [
  [Color(0xFFE6C15A), Color(0xFFB8902F)], // champagne gold
  [Color(0xFF4F8DF7), Color(0xFF2456C8)], // ocean
  [Color(0xFF9B5DE5), Color(0xFF5E2CA5)], // grape
  [Color(0xFFF76E8E), Color(0xFFC8325B)], // rose
  [Color(0xFF3DD2A0), Color(0xFF1E8F6B)], // mint
  [Color(0xFFFF8A5B), Color(0xFFE0453C)], // sunset
  [Color(0xFF5BC8F7), Color(0xFF2A8FC8)], // sky
  [Color(0xFF3A4055), Color(0xFF1B1E28)], // ink
];

/// Curated emoji avatars (append-only).
const List<String> kEmojiAvatars = [
  '🦊', '🐼', '🦁', '🐯', '🐶', '🐱', '🦉', '🐧',
  '🐢', '🐝', '🦄', '🐙', '🚀', '🌟', '🔥', '👑',
];

List<Color> accentOf(int index) =>
    kAvatarAccents[index % kAvatarAccents.length];

// ── Pixel character avatars ────────────────────────────────────────────────
// Distinct hand-authored chibi characters (different hair / headwear / gender,
// male and female), each with its own palette — drawn with a CustomPainter, no
// assets, fully offline. Pixel avatars carry their own colours, so the accent
// picker doesn't apply to them.

const Color _outline = Color(0xFF15171E);
const Color _eyeWhite = Color(0xFFF2F5F8);

/// Glyph → palette slot:
///   .  transparent   X outline    C headwear  c headwear-shadow
///   H  hair          h hair-shadow  K skin     k skin-shadow
///   W  eye-white     I iris        J top       j top-shadow
///   A  accent        a accent-shadow (glows, horns, trims — elite characters)
class _Pal {
  final Color hair, hairD, cap, capD, jacket, jacketD, skin, skinD, iris;
  final Color accent, accentD;
  const _Pal({
    required this.hair, required this.hairD, required this.cap, required this.capD,
    required this.jacket, required this.jacketD, required this.skin,
    required this.skinD, required this.iris,
    this.accent = const Color(0xFFFFFFFF), this.accentD = const Color(0xFFB8B8B8),
  });
}

class _Sprite {
  final List<String> rows;
  final _Pal pal;
  final List<Color> halo; // coordinating gradient for the profile card
  const _Sprite(this.rows, this.pal, this.halo);
}

// Shared face + neck + body for the head-up (no side-hair) characters.
const List<String> _face = [
  '...XKKKKKKKKX...',
  '...XKWWKKWWKX...',
  '...XKIIKKIIKX...',
  '...XKKKKKKKKX...',
  '...XKKKkkKKKX...',
  '....XKKKKKKX....',
  '.....XKKKKX.....',
  '...XXJJJJJJXX...',
  '..XJjJJJJJJjJX..',
  '..XJjJJJJJJjJX..',
  '..XXJJJJJJJJXX..',
];

const List<String> _capHead = [
  '....XXXXXXXX....',
  '...XCCCCCCCCX...',
  '..XCCCCCCCCCCX..',
  '..XCccccccccCX..',
  '..XXXXXXXXXXXX..',
];
const List<String> _shortHead = [
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHhhhhhhhhHX..',
  '..XHKKKKKKKKHX..',
];
const List<String> _beanieHead = [
  '....XXXXXXXX....',
  '...XCCCCCCCCX...',
  '..XCCCCCCCCCCX..',
  '..XCCCCCCCCCCX..',
  '..XCCCCCCCCCCX..',
];
const List<String> _bunHead = [
  '.....XHHX.......',
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHKKKKKKKKHX..',
];
const List<String> _afroHead = [
  '..XHHHHHHHHHHX..',
  '.XHHHHHHHHHHHHX.',
  '.XHHHHHHHHHHHHX.',
  '.XHHHHHHHHHHHHX.',
  '..XHKKKKKKKKHX..',
];
// Long hair frames the face and falls past the neck.
const List<String> _longHair = [
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..HXKKKKKKKKXH..',
  '..HXKWWKKWWKXH..',
  '..HXKIIKKIIKXH..',
  '..HXKKKKKKKKXH..',
  '..HXKKKkkKKKXH..',
  '..HXKKKKKKKKXH..',
  '..HhXKKKKXhH....',
  '...XXJJJJJJXX...',
  '..XJjJJJJJJjJX..',
  '..XJjJJJJJJjJX..',
  '..XXJJJJJJJJXX..',
];

const List<String> _mohawkHead = [
  '......XHHX......',
  '....XXKHHKXX....',
  '...XKKKHHKKKX...',
  '..XKKKKHHKKKKX..',
  '..XKKKKHHKKKKX..',
];
const List<String> _topknotHead = [
  '......XHX.......',
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHKKKKKKKKHX..',
];
// Chin-length bob (hair frames the face, ends at the jaw).
const List<String> _bob = [
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..HXKKKKKKKKXH..',
  '..HXKWWKKWWKXH..',
  '..HXKIIKKIIKXH..',
  '..HXKKKKKKKKXH..',
  '..HXKKKkkKKKXH..',
  '....XKKKKKKX....',
  '.....XKKKKX.....',
  '...XXJJJJJJXX...',
  '..XJjJJJJJJjJX..',
  '..XJjJJJJJJjJX..',
  '..XXJJJJJJJJXX..',
];

List<String> _stack(List<String> head) => [...head, ..._face];

const _skinLight = Color(0xFFF2C9A0);
const _skinLightD = Color(0xFFD9A87C);
const _skinMed = Color(0xFFE8B98C);
const _skinMedD = Color(0xFFCE9B6E);
const _skinDark = Color(0xFF8D5A3A);
const _skinDarkD = Color(0xFF6F4329);

final List<_Sprite> _sprites = [
  // Capped (masc) — the agent look.
  _Sprite(_stack(_capHead),
      const _Pal(hair: Color(0xFF3A3F4A), hairD: Color(0xFF2A2E37), cap: Color(0xFF3A3F4A), capD: Color(0xFF2A2E37), jacket: Color(0xFF2F343E), jacketD: Color(0xFF21252D), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF5BD68A)),
      const [Color(0xFF4A5160), Color(0xFF2A2E37)]),
  // Short hair (masc).
  _Sprite(_stack(_shortHead),
      const _Pal(hair: Color(0xFF6B4423), hairD: Color(0xFF4A2E16), cap: Color(0xFF6B4423), capD: Color(0xFF4A2E16), jacket: Color(0xFF2D6CDF), jacketD: Color(0xFF1E4DA8), skin: _skinMed, skinD: _skinMedD, iris: Color(0xFF7A4B28)),
      const [Color(0xFF4F8DF7), Color(0xFF2456C8)]),
  // Beanie (unisex).
  _Sprite(_stack(_beanieHead),
      const _Pal(hair: Color(0xFFA23B4A), hairD: Color(0xFF74222E), cap: Color(0xFFA23B4A), capD: Color(0xFF74222E), jacket: Color(0xFF4A5563), jacketD: Color(0xFF333B45), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF3A3F4A)),
      const [Color(0xFFC0566A), Color(0xFF74222E)]),
  // Long hair (fem).
  _Sprite(_longHair,
      const _Pal(hair: Color(0xFF2E2A33), hairD: Color(0xFF1C1A20), cap: Color(0xFF2E2A33), capD: Color(0xFF1C1A20), jacket: Color(0xFFE05C86), jacketD: Color(0xFFB23C64), skin: _skinMed, skinD: _skinMedD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFFF076A0), Color(0xFFB23C64)]),
  // Top bun (fem), blonde.
  _Sprite(_stack(_bunHead),
      const _Pal(hair: Color(0xFFE6C15A), hairD: Color(0xFFC09A38), cap: Color(0xFFE6C15A), capD: Color(0xFFC09A38), jacket: Color(0xFF2BB9A0), jacketD: Color(0xFF1C8A78), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF5B8FE0)),
      const [Color(0xFF3DD2B8), Color(0xFF1C8A78)]),
  // Afro (unisex), dark skin.
  _Sprite(_stack(_afroHead),
      const _Pal(hair: Color(0xFF2A2530), hairD: Color(0xFF18151C), cap: Color(0xFF2A2530), capD: Color(0xFF18151C), jacket: Color(0xFFF0883C), jacketD: Color(0xFFC76B26), skin: _skinDark, skinD: _skinDarkD, iris: Color(0xFF3A2E28)),
      const [Color(0xFFFF9E55), Color(0xFFC76B26)]),
  // Bob cut (fem), dark-brown hair.
  _Sprite(_bob,
      const _Pal(hair: Color(0xFF4A2E16), hairD: Color(0xFF2E1C0E), cap: Color(0xFF4A2E16), capD: Color(0xFF2E1C0E), jacket: Color(0xFF2BB9A0), jacketD: Color(0xFF1C8A78), skin: _skinMed, skinD: _skinMedD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFF3DD2B8), Color(0xFF1C8A78)]),
  // Mohawk (masc), electric-blue.
  _Sprite(_stack(_mohawkHead),
      const _Pal(hair: Color(0xFF2D6CDF), hairD: Color(0xFF1E4DA8), cap: Color(0xFF2D6CDF), capD: Color(0xFF1E4DA8), jacket: Color(0xFF2A2E37), jacketD: Color(0xFF1C1F26), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF3A3F4A)),
      const [Color(0xFF4F8DF7), Color(0xFF2456C8)]),
  // Top-knot (unisex), black hair.
  _Sprite(_stack(_topknotHead),
      const _Pal(hair: Color(0xFF2E2A33), hairD: Color(0xFF1C1A20), cap: Color(0xFF2E2A33), capD: Color(0xFF1C1A20), jacket: Color(0xFF7E4FD6), jacketD: Color(0xFF5A37A0), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFF9B5DE5), Color(0xFF5E2CA5)]),
  // Long hair (fem), blonde.
  _Sprite(_longHair,
      const _Pal(hair: Color(0xFFE6C15A), hairD: Color(0xFFC09A38), cap: Color(0xFFE6C15A), capD: Color(0xFFC09A38), jacket: Color(0xFFE05C86), jacketD: Color(0xFFB23C64), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF5BD68A)),
      const [Color(0xFFF076A0), Color(0xFFB23C64)]),
  // Short hair (masc), dark skin.
  _Sprite(_stack(_shortHead),
      const _Pal(hair: Color(0xFF2A2530), hairD: Color(0xFF18151C), cap: Color(0xFF2A2530), capD: Color(0xFF18151C), jacket: Color(0xFF2BB985), jacketD: Color(0xFF1C8A62), skin: _skinDark, skinD: _skinDarkD, iris: Color(0xFF3A2E28)),
      const [Color(0xFF3DD2A0), Color(0xFF1E8F6B)]),
  // Afro (unisex), brown hair + light skin.
  _Sprite(_stack(_afroHead),
      const _Pal(hair: Color(0xFF6B4423), hairD: Color(0xFF4A2E16), cap: Color(0xFF6B4423), capD: Color(0xFF4A2E16), jacket: Color(0xFF2D6CDF), jacketD: Color(0xFF1E4DA8), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFF4F8DF7), Color(0xFF2456C8)]),

  // ── Elite characters (order must mirror kEliteAvatars) ──────────────────
  // Shadow Blade: deep hood, shadowed face, cyan glow eyes, masked mouth.
  _Sprite(const [
    '................',
    '....XXXXXXXX....',
    '...XCCCCCCCCX...',
    '..XCCCCCCCCCCX..',
    '..XCCccccccCCX..',
    '..XCcKKKKKKcCX..',
    '..XCKAAKKAAKCX..',
    '..XCKKKKKKKKCX..',
    '..XCKJJJJJJKCX..',
    '...XKJJJJJJKX...',
    '.....XJJJJX.....',
    '...XXJJJJJJXX...',
    '..XJjJJJJJJjJX..',
    '..XJaJJJJJJaJX..',
    '..XXJJJJJJJJXX..',
    '................',
  ],
      const _Pal(hair: Color(0xFF23262F), hairD: Color(0xFF15171D), cap: Color(0xFF2B2F3B), capD: Color(0xFF1B1E26), jacket: Color(0xFF1D2027), jacketD: Color(0xFF14161C), skin: Color(0xFF44506A), skinD: Color(0xFF303A50), iris: Color(0xFF4DE0FF), accent: Color(0xFF4DE0FF), accentD: Color(0xFF2596B8)),
      const [Color(0xFF35B6E0), Color(0xFF16324A)]),
  // Crimson Oni: horned war mask, bone-white face, burning eyes.
  _Sprite(const [
    '..A..........A..',
    '..AA.XXXXXX.AA..',
    '...XXCCCCCCXX...',
    '..XCCCCCCCCCCX..',
    '..XCcCCCCCCcCX..',
    '..XCKKKKKKKKCX..',
    '..XCKIIKKIIKCX..',
    '..XCKKKKKKKKCX..',
    '..XCKkKKKKkKCX..',
    '...XKKKKKKKKX...',
    '.....XKKKKX.....',
    '...XXJJJJJJXX...',
    '..XJjJJJJJJjJX..',
    '..XJaJJJJJJaJX..',
    '..XXJJJJJJJJXX..',
    '................',
  ],
      const _Pal(hair: Color(0xFFB02832), hairD: Color(0xFF7E1820), cap: Color(0xFFB02832), capD: Color(0xFF7E1820), jacket: Color(0xFF2A2027), jacketD: Color(0xFF1C1519), skin: Color(0xFFF2E8D8), skinD: Color(0xFFD8C4A8), iris: Color(0xFFFF4632), accent: Color(0xFFF2C14E), accentD: Color(0xFFC09232)),
      const [Color(0xFFFF5A4E), Color(0xFF7E1820)]),
  // Cyber Ronin: gunmetal helm, teal visor band, respirator, lit armour seams.
  _Sprite(const [
    '................',
    '....XXXXXXXX....',
    '...XCCCCCCCCX...',
    '..XCCCCCCCCCCX..',
    '..XCcCCCCCCcCX..',
    '..XAAAAAAAAAAX..',
    '..XaAAaAAaAAaX..',
    '..XCKKKKKKKKCX..',
    '..XCKKJJJJKKCX..',
    '...XKKJJJJKKX...',
    '.....XJJJJX.....',
    '...XXJJJJJJXX...',
    '..XJjJJJJJJjJX..',
    '..XJAJJJJJJAJX..',
    '..XXJJJJJJJJXX..',
    '................',
  ],
      const _Pal(hair: Color(0xFF6E7686), hairD: Color(0xFF4C5260), cap: Color(0xFF6E7686), capD: Color(0xFF4C5260), jacket: Color(0xFF262B36), jacketD: Color(0xFF191D25), skin: Color(0xFF9AA3B2), skinD: Color(0xFF7B8494), iris: Color(0xFF21E6C1), accent: Color(0xFF21E6C1), accentD: Color(0xFF139C82)),
      const [Color(0xFF21E6C1), Color(0xFF17546E)]),
  // Dragon Lord: crested drake helm, side horns, ember eyes, gilded scale.
  _Sprite(const [
    '.......AA.......',
    '....XX.AA.XX....',
    '...XCCXAAXCCX...',
    '..XCCCCAACCCCX..',
    '.AXCCCCCCCCCCXA.',
    '.AXCcCCCCCCcCXA.',
    '..XCKKKKKKKKCX..',
    '..XCKIIKKIIKCX..',
    '..XCKKKKKKKKCX..',
    '..XCKkkKKkkKCX..',
    '.....XKKKKX.....',
    '...XXJJJJJJXX...',
    '..XJaJJJJJJaJX..',
    '..XJjaJJJJajJX..',
    '..XXJJJJJJJJXX..',
    '................',
  ],
      const _Pal(hair: Color(0xFF2F8757), hairD: Color(0xFF1F5E3C), cap: Color(0xFF2F8757), capD: Color(0xFF1F5E3C), jacket: Color(0xFF23402E), jacketD: Color(0xFF16291D), skin: Color(0xFF57B87A), skinD: Color(0xFF3B8A58), iris: Color(0xFFFFB300), accent: Color(0xFFF2C14E), accentD: Color(0xFFC09232)),
      const [Color(0xFF3DD27E), Color(0xFF1F5E3C)]),
  // Void Monarch: gold crown, void-pale face, blank glowing eyes, royal robe.
  _Sprite(const [
    '...A...A...A....',
    '...AAAAAAAAA....',
    '...XHHHHHHHHX...',
    '..XHHHHHHHHHHX..',
    '..XHKKKKKKKKHX..',
    '..XHKWWKKWWKHX..',
    '..XHKKKKKKKKHX..',
    '..XHKKKkkKKKHX..',
    '....XKKKKKKX....',
    '.....XKKKKX.....',
    '...XXJJJJJJXX...',
    '..XJaJJJJJJaJX..',
    '..XJJaJJJJaJJX..',
    '..XJJJaaaaJJJX..',
    '..XXJJJJJJJJXX..',
    '................',
  ],
      const _Pal(hair: Color(0xFF2A2440), hairD: Color(0xFF1A1628), cap: Color(0xFF2A2440), capD: Color(0xFF1A1628), jacket: Color(0xFF3A2E6E), jacketD: Color(0xFF291F52), skin: Color(0xFFC9CBE8), skinD: Color(0xFFA6A8CC), iris: Color(0xFFFFFFFF), accent: Color(0xFFF2C14E), accentD: Color(0xFFC09232)),
      const [Color(0xFF8F7BFF), Color(0xFF2A2050)]),
  // Eternal Phoenix: living flame crest, ember eyes, molten plumage armour.
  _Sprite(const [
    '....A...A..A....',
    '...AA..AA..AA...',
    '...XAAAAAAAAX...',
    '..XHAAHHHHAAHX..',
    '..XHHHHHHHHHHX..',
    '..XHKKKKKKKKHX..',
    '..XHKIIKKIIKHX..',
    '..XHKKKKKKKKHX..',
    '..XHKKKkkKKKHX..',
    '....XKKKKKKX....',
    '.....XKKKKX.....',
    '...XXJJJJJJXX...',
    '..XJjJJJJJJjJX..',
    '..XJaJJJJJJaJX..',
    '..XXJJJJJJJJXX..',
    '................',
  ],
      const _Pal(hair: Color(0xFFE85D20), hairD: Color(0xFFB03E12), cap: Color(0xFFE85D20), capD: Color(0xFFB03E12), jacket: Color(0xFF8C2B12), jacketD: Color(0xFF621D0B), skin: _skinMed, skinD: _skinMedD, iris: Color(0xFFFF8C00), accent: Color(0xFFFFB347), accentD: Color(0xFFFF6B35)),
      const [Color(0xFFFFB347), Color(0xFFB03E12)]),
];

/// Number of distinct pixel-character avatars offered (free + elite +
/// royal). Royal characters live in royal_avatars.dart and occupy the sprite
/// slots directly after the elite block (append-only, persisted).
final int kPixelAvatarCount = _sprites.length + kRoyalAvatars.length;

/// An elite pixel character: prestige art shown in its own picker section.
/// [spriteIndex] is its slot in the shared sprite list (persisted in
/// profiles — append-only). All elite characters are unlocked for everyone;
/// the category only marks out the showpiece art.
class EliteAvatar {
  final String id;
  final int spriteIndex;
  const EliteAvatar({
    required this.id,
    required this.spriteIndex,
  });
}

/// The elite roster, in sprite order right after the free characters.
const List<EliteAvatar> kEliteAvatars = [
  EliteAvatar(id: 'shadowblade', spriteIndex: 12),
  EliteAvatar(id: 'crimsononi', spriteIndex: 13),
  EliteAvatar(id: 'cyberronin', spriteIndex: 14),
  EliteAvatar(id: 'dragonlord', spriteIndex: 15),
  EliteAvatar(id: 'voidmonarch', spriteIndex: 16),
  EliteAvatar(id: 'phoenix', spriteIndex: 17),
];

/// Number of free (always available) pixel characters — elite sprites start
/// at this index.
final int kFreePixelAvatarCount = _sprites.length - kEliteAvatars.length;

/// The elite character occupying [spriteIndex], or null for a free one.
EliteAvatar? eliteAvatarAt(int spriteIndex) {
  for (final e in kEliteAvatars) {
    if (e.spriteIndex == spriteIndex) return e;
  }
  return null;
}

/// Test hook: raw glyph rows of sprite [i], for grid-integrity checks.
@visibleForTesting
List<String> debugSpriteRows(int i) =>
    royalAvatarAt(i)?.rows ?? _sprites[i % _sprites.length].rows;

/// Coordinating halo gradient for a pixel avatar (used on the profile card).
/// Royal characters carry their halo on their [RoyalTheme].
List<Color> pixelHaloOf(int seed) =>
    royalAvatarAt(seed)?.theme.halo ?? _sprites[seed % _sprites.length].halo;

/// Renders a user's avatar from its persisted `{kind, value, accent}`. Used in
/// the Home header, profile, share card and picker so they always match.
/// (Accent applies to emoji avatars only — pixel characters carry own colours.)
class AvatarView extends StatelessWidget {
  final String kind; // 'emoji' | 'pixel'
  final String value; // emoji glyph or pixel sprite index
  final int accent;
  final double size;
  final bool ring;

  /// Whether an equipped royal plays its spawn flourish when this view
  /// mounts. Grids of small tiles pass false so a whole section doesn't
  /// burst at once.
  final bool spawnRoyals;

  /// Set false where a live ticker is unwanted (share captures).
  final bool animateRoyals;

  const AvatarView({
    super.key,
    required this.kind,
    required this.value,
    required this.accent,
    this.size = 48,
    this.ring = true,
    this.spawnRoyals = true,
    this.animateRoyals = true,
  });

  @override
  Widget build(BuildContext context) {
    final border = ring
        ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: size * 0.03)
        : null;

    final Widget inner;
    final royal = kind == 'pixel' ? royalAvatarAt(int.tryParse(value) ?? 0) : null;
    if (royal != null) {
      // Royal characters are living avatars on their own velvet backdrop.
      inner = AnimatedRoyalAvatar(
        royal: royal,
        size: size,
        spawn: spawnRoyals,
        animate: animateRoyals,
      );
    } else if (kind == 'pixel') {
      inner = DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEDEFF3), Color(0xFFC9CFD8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.05),
          child: CustomPaint(
            size: Size.square(size),
            painter: PixelAvatarPainter(seed: int.tryParse(value) ?? 0),
          ),
        ),
      );
    } else {
      inner = Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: accentOf(accent),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Text(value, style: TextStyle(fontSize: size * 0.52)),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: border),
      child: ClipOval(child: inner),
    );
  }
}

/// Paints the chibi character for the chosen [seed] sprite. Crisp pixel squares,
/// transparent background (the [AvatarView] supplies the backdrop).
class PixelAvatarPainter extends CustomPainter {
  final int seed;
  const PixelAvatarPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    // Royal seeds: delegate to the royal painter's static frame (no
    // backdrop — this painter's contract is a transparent background).
    final royal = royalAvatarAt(seed);
    if (royal != null) {
      RoyalAvatarPainter(royal: royal, t: 0.05, backdrop: false)
          .paint(canvas, size);
      return;
    }
    final sprite = _sprites[seed % _sprites.length];
    final pal = sprite.pal;
    final rows = sprite.rows;
    final cols = rows.first.length;
    final cell = size.width / cols;
    final paint = Paint()..isAntiAlias = false;

    Color? colorFor(String ch) => switch (ch) {
          'X' => _outline,
          'C' => pal.cap,
          'c' => pal.capD,
          'H' => pal.hair,
          'h' => pal.hairD,
          'K' => pal.skin,
          'k' => pal.skinD,
          'W' => _eyeWhite,
          'I' => pal.iris,
          'J' => pal.jacket,
          'j' => pal.jacketD,
          'A' => pal.accent,
          'a' => pal.accentD,
          _ => null,
        };

    for (var r = 0; r < rows.length; r++) {
      final line = rows[r];
      for (var c = 0; c < line.length; c++) {
        final color = colorFor(line[c]);
        if (color == null) continue;
        paint.color = color;
        // +0.5 overscan avoids hairline seams between cells.
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PixelAvatarPainter old) => old.seed != seed;
}
