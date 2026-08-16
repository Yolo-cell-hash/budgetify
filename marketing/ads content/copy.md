# Google Ads — App campaign copy

> Paste into **Google Ads → your App campaign → Ad group → Ad assets**.
> Limits: headline **30**, description **90**.
> Run `python3 validate.py` before pasting — it fails on anything over.

An App campaign mixes and matches these itself: any headline can appear beside
any description, and often beside neither. So every line below has to stand on
its own. Nothing here continues a sentence started somewhere else, and nothing
refers to "above" or "below".

Google also pulls your Play Store icon, feature graphic and screenshots into the
ad automatically — that is why the preview already shows a banner with zero
images uploaded. What you upload here **competes with** those, it does not
replace them.

---

## The five headlines  `≤30`

```
Expense tracker, no internet
It reads your bank SMS
No sign-up. No cloud. No ads.
Budget tracker, zero typing
Works in airplane mode
```

Two of the five carry a category head term (`expense tracker`, `budget tracker`)
because App campaign headlines also serve on Search inventory, where the words
someone typed still matter. The other three carry the wedge — the reasons a
person who cares about privacy picks this over a free tracker that phones home.

## The five descriptions  `≤90`

```
Reads the bank and UPI SMS you already get, and logs every transaction for you.
The release build has no internet permission. Your money data cannot leave the phone.
Budgets, categories, net worth and recurring bills — all on-device, all offline.
No account, no cloud, no ads, no trackers. Just where your money actually went.
Six languages. Works in airplane mode. Nothing to sign up for, ever.
```

---

## Alternates

Swap these in when an asset is marked "Low" in the asset report. Change one at a
time — replacing the whole set at once restarts learning and tells you nothing
about which line moved the number.

### Headlines

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

### Descriptions

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
| No internet permission | Release manifest strips `INTERNET`; see [[play-console-16kb-and-edge-to-edge]] and the store listing's own wording |
| Reads bank & UPI SMS | `sms_parser_service.dart` — the product's core loop |
| No sign-up / no account | No auth anywhere in the app |
| No ads, no trackers, no analytics | No ad SDK, no telemetry — a consequence of having no network access |
| Works in airplane mode | Nothing in the app needs a network round-trip |
| Six languages | `l10n/` — en, hi, mr, bn, te, ta |
| Budgets, net worth, recurring | Shipped feature families; all four appear in the film and the screenshots |

## What is deliberately NOT claimed

- **No "free" or "100% free".** Budgetify Plus is a real in-app purchase. Play
  renders its own "Free" install badge and the IAP disclosure; saying it in ad
  copy on top of that invites a "misleading" flag and, worse, a one-star review
  from someone who felt bait-and-switched.
- **No "#1", "best" or "most accurate".** Unverifiable superlatives are a
  Google Ads policy risk and cost nothing to drop.
- **No install or user counts.** The number is small; do not draw attention to
  it, and do not invent one.
- **No named competitors.** Play's metadata policy treats cross-references as
  irrelevant keywords, and the same instinct is right here.
