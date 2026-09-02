# Royal avatar product icons + Console copy

The eight `royal_*` one-time products, ready to type into
**Play Console → Monetise with Play → Products → One-time products → Create
one-time product**. One row per royal: the Product ID the app asks Play for,
the icon to upload, and the Name/Description the form requires.

Everything here is the everyday catalogue. The app treats these numbers as a
FALLBACK and quotes Play's own answer once the store replies, so what the
Console says is what the picker shows.

## The form, field by field

| Field | What to enter |
| --- | --- |
| **Product ID** | Exactly as listed below. `royalProductId()` in `lib/models/plus_products.dart` builds it as `royal_<royal id>`, and Play never lets you change or reuse an ID once created. |
| **Tags** | **Leave empty.** This is a Console organisation field. It is NOT `kPlusOfferTag` (`plus-offer`), which lives on *subscription offers* and is read by `selectEntry` in `play_billing_gateway.dart`. |
| **Name** | Column below. Under Play's 55. |
| **Description** | Column below. Under Play's 200. |
| **Icon** | The PNG in this folder. 1024x1024, 32-bit, 1:1, ~500KB — inside Play's 512-1080px / 8MB limits. |
| **Price** | **₹49** (`kRoyalAvatarPriceInr`). Let Play auto-convert other storefronts; the picker renders Play's own formatted, tax-inclusive string, so no other currency needs a hand-set number. |
| **Availability** | Same countries as the app. |
| **Status** | **Active** — an inactive product is invisible to `queryProductDetails`, and the picker silently falls back to the ₹49 constant. |

⚠️ **`royal_royalmedic` is not a typo.** Her display name is "The Apothecary",
but her persisted id stayed `royalmedic` — it is written into profiles, into
RoyalSkinService's prefs key and into RoyalAppIcon, so renaming it would revoke
her from everyone who spent a streak pick on her. The product ID has to match
the id, not the name.

## The eight products

### `royal_sovereign`

**Icon:** `royal_sovereign.png`

**Name** (28/55)

```
The Sovereign — Royal Avatar
```

**Description** (195/200)

```
The founding king, in crimson robes and an ermine collar under a crown of rubies. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

### `royal_empress`

**Icon:** `royal_empress.png`

**Name** (26/55)

```
The Empress — Royal Avatar
```

**Description** (193/200)

```
The raven-haired matriarch: a sapphire tiara, a violet gown, and quiet command. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

### `royal_prince`

**Icon:** `royal_prince.png`

**Name** (25/55)

```
The Prince — Royal Avatar
```

**Description** (187/200)

```
The heir in gilded plate with his sword in hand — radiant, eager, golden. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

### `royal_darkprince`

**Icon:** `royal_darkprince.png`

**Name** (30/55)

```
The Dark Prince — Royal Avatar
```

**Description** (182/200)

```
The exiled brother: black plate, ember eyes, and a studded war club. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

### `royal_princess`

**Icon:** `royal_princess.png`

**Name** (27/55)

```
The Princess — Royal Avatar
```

**Description** (185/200)

```
Elegance itself — a blush-gem tiara, a rope of pearls, and a rose gown. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

### `royal_royalmedic`

**Icon:** `royal_royalmedic.png`

**Name** (29/55)

```
The Apothecary — Royal Avatar
```

**Description** (191/200)

```
The court apothecary, marked by the emerald cross of life and tireless hands. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

### `royal_sentinel`

**Icon:** `royal_sentinel.png`

**Name** (27/55)

```
The Sentinel — Royal Avatar
```

**Description** (190/200)

```
The crown's sworn guard: steel plate, a sapphire visor, and no face to read. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

### `royal_huntress`

**Icon:** `royal_huntress.png`

**Name** (27/55)

```
The Huntress — Royal Avatar
```

**Description** (185/200)

```
Nobility gone to the road, with paired blades and no horse to slow her. A living avatar: it blinks, waves, and dresses the app in this court's colour. One-time purchase, yours for good.
```

## Discounts: edit the price, never add an offer

During an offer window (`lib/models/plus_offers.dart`) the royals drop to
**₹29** alongside Plus. Do that as a **price edit on the product**, and put it
back when the window closes.

Do *not* create a Play "offer" on these. `selectEntry` picks a discount by the
`plus-offer` tag, and offer tags only exist on subscription offers — a one-time
product comes back from Play as a single untagged entry, so an offer on it
would be quoted and charged by luck rather than by the calendar. `plus_lifetime`
already follows the same rule.

Forgetting the edit is safe: the picker only draws the struck-through ₹49 when
Play's own amount is genuinely lower, so an unmatched window simply shows the
full price and claims nothing.

## Regenerating the icons

The art is 16x16 glyph rows in `lib/widgets/royal_avatars.dart`, so the icons
are painted by the app's own `RoyalAvatarPainter` rather than redrawn — a
lookalike in SVG would drift the first time a sprite is tweaked. The ground is
the same ink the Plus icons stand on, with the bloom and hairline taking each
royal's court colour.

```
flutter test test/royal_product_icon_test.dart \
  --dart-define=ROYAL_ICON_OUT=marketing/subscriptions/royals
```

Re-run it after any change to a royal's sprite or palette, and re-upload —
Play's guidance is "a unique and accurate image for each product", and an icon
showing last month's crown is neither. No text, no wordmark and no price is
drawn, per the form's "don't include text, promotions or branding".
