# Google Ads — App campaign copy

> **Google Ads → your App campaign → Ad group → Ad assets.**
> One block below per field. Limits: headline **30**, description **90**.
> `python3 validate.py` fails the set if anything runs over.

This file holds **two ad groups' worth of copy**: English first, then Hindi.
Keep them in separate ad groups — the reason is in the Hindi section below.

An App campaign mixes these itself: any headline can appear beside any
description, and often beside neither. So every line stands on its own — nothing
continues a sentence started elsewhere, and nothing refers to "above" or "below".
That is exactly what Google's own panel asks for when it says each headline must
make sense alone *and* paired with any other asset.

---

# Headlines — paste one per field

### Headline 1 &nbsp;`28/30`

```
Expense tracker, no internet
```

### Headline 2 &nbsp;`22/30`

```
It reads your bank SMS
```

### Headline 3 &nbsp;`29/30`

```
No sign-up. No cloud. No ads.
```

### Headline 4 &nbsp;`27/30`

```
Budget tracker, zero typing
```

### Headline 5 &nbsp;`22/30`

```
Works in airplane mode
```

Two of the five carry a category head term (`expense tracker`, `budget tracker`)
because App campaign headlines also serve on Search inventory, where the words
someone typed still matter. The other three carry the wedge — the reasons
someone picks this over a free tracker that phones home.

---

# Descriptions — paste one per field

### Description 1 &nbsp;`79/90`

```
Reads the bank and UPI SMS you already get, and logs every transaction for you.
```

### Description 2 &nbsp;`85/90`

```
The release build has no internet permission. Your money data cannot leave the phone.
```

### Description 3 &nbsp;`80/90`

```
Budgets, categories, net worth and recurring bills — all on-device, all offline.
```

### Description 4 &nbsp;`79/90`

```
No account, no cloud, no ads, no trackers. Just where your money actually went.
```

### Description 5 &nbsp;`68/90`

```
Six languages. Works in airplane mode. Nothing to sign up for, ever.
```

---

# हिन्दी — the second ad group

> **Parked as of 2026-09-03.** The first flight runs English-only: one language
> is one variable, and an App campaign already needs volume before its asset
> report says anything. This section is ready to paste the day a Hindi ad group
> is worth opening — it is not a to-do.

The campaign targets India in **English and Hindi**, and until now every asset
in this folder was English. A Hindi-language user served an English headline is
a click you paid for and a page they bounce off.

**These do not go in the same ad group as the English lines.** An App campaign
mixes assets freely inside one ad group, so a shared group would serve a
Devanagari headline over an English description. Two ad groups, one script each,
and the asset report then tells you which language pulls.

The lines below are the English five, translated — not new claims. Every one is
already verified in the table at the bottom of this file, and every one matches
the wording of the Hindi custom store listing in
`../playstore/listing/localized.md`, so the ad and the page it lands on say the
same thing in the same words.

> **Character counts are the conservative reading.** Google counts Devanagari as
> single-width, but a matra is its own code point, so `बैंक` is four characters,
> not two. `validate.py` counts the same way. Nothing here is over 29, which
> leaves room if Google's own counter disagrees by one.

## Hindi headlines — paste one per field

### Hindi headline 1 &nbsp;`25/30`

```
खर्च ट्रैकर, बिना इंटरनेट
```

### Hindi headline 2 &nbsp;`24/30`

```
बैंक SMS खुद पढ़ लेता है
```

### Hindi headline 3 &nbsp;`24/30`

```
आपका पैसा, आपके फ़ोन में
```

### Hindi headline 4 &nbsp;`24/30`

```
बजट ट्रैकर, बिना टाइपिंग
```

### Hindi headline 5 &nbsp;`27/30`

```
एयरप्लेन मोड में भी चलता है
```

`SMS`, `UPI` and `EMI` stay in Latin script on purpose — that is how they are
written on every bank message an Indian phone receives, and transliterating them
would make the ad less recognisable, not more local.

## Hindi descriptions — paste one per field

### Hindi description 1 &nbsp;`79/90`

```
आपके बैंक और UPI SMS पढ़कर हर लेन-देन अपने आप दर्ज करता है। कुछ टाइप नहीं करना।
```

### Hindi description 2 &nbsp;`83/90`

```
रिलीज़ बिल्ड में इंटरनेट परमिशन ही नहीं है। आपका डेटा फ़ोन से बाहर जा ही नहीं सकता।
```

### Hindi description 3 &nbsp;`77/90`

```
बजट, कैटेगरी, नेट वर्थ और रिकरिंग बिल — सब आपके फ़ोन पर, सब पूरी तरह ऑफ़लाइन।
```

### Hindi description 4 &nbsp;`78/90`

```
न अकाउंट, न क्लाउड, न विज्ञापन, न ट्रैकर। बस यह कि आपका पैसा असल में कहाँ गया।
```

### Hindi description 5 &nbsp;`72/90`

```
छह भाषाएँ। एयरप्लेन मोड में भी चलता है। साइन-अप करने की ज़रूरत कभी नहीं।
```

## Hindi alternate headlines

```
इंटरनेट परमिशन नहीं
ऑफ़लाइन खर्च ट्रैकर
हर रुपया अपने आप दर्ज
UPI खर्च अपने आप ट्रैक
बिना टाइप किए खर्च ट्रैक
न अकाउंट, न क्लाउड, न ऐड
बैंक SMS से खर्च ट्रैक करें
आपका डेटा फ़ोन में ही रहता है
```

## Hindi alternate descriptions

```
कैटेगरी बजट तय करें और रोज़ की रफ़्तार देखें। न स्प्रेडशीट, न मैनुअल एंट्री।
सब्सक्रिप्शन और EMI बिल आने से पहले पकड़ें। सब कुछ आपके फ़ोन पर ही रहता है।
Excel, CSV या PDF में कभी भी एक्सपोर्ट करें। एक टैप में कुछ भी हटाएँ। सब आपका है।
```

---

# Hinglish — the third ad group, if you want it

Plenty of the audience sets its phone to English, thinks in Hindi, and types in
Roman script. Those users are targeted by the **English** ad group and served
English lines. Roman-script Hindi is a third bet, and it is a real one in India —
but it is a bet, so treat it as a test with its own ad group rather than as
copy you mix into either of the other two.

Do not run this until English and Hindi have both had a fair run. Three ad
groups split the same budget three ways, and an App campaign already needs
volume to learn.

### Hinglish headlines

```
Bank SMS se kharch track
Bina type kiye kharch track
Poori tarah offline tracker
Har rupee apne aap track
Na account, na cloud, na ads
```

### Hinglish descriptions

```
Aapke bank aur UPI SMS padhkar har transaction khud record karta hai.
Release build mein internet permission hi nahi hai. Data phone se bahar nahi jata.
Budget, category, net worth aur recurring bills — sab phone par, sab offline.
```

---

## Also uploaded with these

| Asset | Where |
|-------|-------|
| 20 images (8 concepts, up to 3 ratios each) | `images/` |
| 4 videos (15s + 30s, 9:16 + 1:1) | `video/` — upload to YouTube as **unlisted** first |
| Feature graphic | `../playstore/feature-graphic.png` — Play pulls this into ads automatically |

The images carry English overlay text, so today they belong to the English ad
group. The Hindi group can run on them anyway — Google draws its own headline
over the creative and `05-product` has no words on it at all — but a Hindi set
is the obvious next asset to build.

---

## Alternates

Swap these in when an asset is marked "Low" in the asset report. Change **one at
a time** — replacing the whole set at once restarts learning and tells you
nothing about which line moved the number.

### Alternate headlines

```
Tracks UPI spends offline
Your bank SMS does the typing
No internet permission
Money manager, fully offline
Every rupee, tracked
Offline expense tracker
See where it actually went
No ads. No trackers. Ever.
Auto-logs bank & UPI SMS
Spending tracker for India
```

### Alternate descriptions

```
Set category budgets and watch your daily pace. No spreadsheet, no manual entry.
Spot subscriptions and EMIs before they bill you. Everything stays on your phone.
Track spending automatically from bank SMS. No login, no bank connection needed.
Your money data never leaves the device — because the app cannot send it anywhere.
Export to Excel, CSV or PDF anytime. Delete anything in a tap. It is all yours.
Most trackers ask you to type. This one reads the message your bank already sent.
```

---

## Every claim, and where it is verified

| Claim in the copy | Verified against |
|---|---|
| No internet permission | Release manifest strips `INTERNET` |
| Reads bank & UPI SMS | `sms_parser_service.dart` — the product's core loop |
| No sign-up / no account | No auth anywhere in the app |
| No ads, no trackers, no analytics | No ad SDK, no telemetry — a consequence of having no network access |
| Works in airplane mode | Nothing in the app needs a network round-trip |
| Six languages | `l10n/` — en, hi, mr, bn, te, ta |
| Budgets, net worth, recurring | Shipped feature families; all appear in the film and screenshots |

## What is deliberately NOT claimed

- **No "free" or "100% free".** Budgetify Plus is a real in-app purchase. Play
  renders its own "Free" install badge and the IAP disclosure; saying it in ad
  copy on top of that invites a "misleading" flag and, worse, a one-star review
  from someone who felt bait-and-switched.
- **No "#1", "best" or "most accurate".** Unverifiable superlatives are a Google
  Ads policy risk and cost nothing to drop.
- **No install or user counts.** The number is small; do not draw attention to
  it, and do not invent one.
- **No named competitors.** Play's metadata policy treats cross-references as
  irrelevant keywords, and the same instinct is right here.
