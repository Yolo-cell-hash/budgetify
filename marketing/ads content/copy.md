# Google Ads — App campaign copy

> **Google Ads → your App campaign → Ad group → Ad assets.**
> One block below per field. Limits: headline **30**, description **90**.
> `python3 validate.py` fails the set if anything runs over.

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

## Also uploaded with these

| Asset | Where |
|-------|-------|
| 20 images (8 concepts across 3 ratios) | `images/` |
| 12 videos (4 ads × 9:16, 1:1, 16:9) | `video/` — upload to YouTube as **unlisted** first |
| Feature graphic | `../playstore/feature-graphic.png` — Play pulls this into ads automatically |

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
