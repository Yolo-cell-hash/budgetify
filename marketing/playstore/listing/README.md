# Why Budgetify is invisible in Play search, and what fixes it

_Measured 2026-08-08 against the live listing (v1.44.3 on store, 5+ installs, 0 ratings)._

## The finding

Budgetify ranks **#1 for `budgetify`** and is **absent from the first page of
all 18 non-brand queries** tested — including queries whose entire result set is
only 11–14 apps.

```
budgetify                          #1   (of 12 results)
budget tracker                      —   (of 30 results)
expense tracker                     —   (of 30 results)
offline expense tracker             —   (of 29 results)
expense tracker without internet    —   (of 12 results)
upi expense tracker                 —   (of 12 results)
…
ranking for 1/19 queries
```

Full baseline in [`baseline-2026-08-08.json`](baseline-2026-08-08.json);
reproduce with [`../aso_rank.py`](../aso_rank.py).

## The cause is the title, not the install count

The obvious theory is that a 5-install app is too small to rank. **That theory
is wrong**, and it is worth being precise about why, because it changes what we
should spend effort on.

Ranking #9 for `offline expense tracker` is **"Income Expense Tracker"** — an app
with **10+ installs**. It is the same size as us and it outranks us, because its
title contains the words being searched for. The same holds all the way down
those result pages:

| # | App ranking for `offline expense tracker` | Installs |
|---|---|---|
| 1 | zero: **offline expense tracker** | 1K+ |
| 5 | **Expense Tracker** App - BudgetIt | 5K+ |
| 6 | **Expense Tracker Offline** | 1K+ |
| 9 | Income **Expense Tracker** | **10+** |
| 10 | **Budget** Planner - **Offline** | 1K+ |

Every one of them puts the query words in the title. Ours is:

```
Budgetify
```

Ten characters of a 30-character field, containing **no category keyword at
all**. The title is the heaviest text-relevance signal in Play search, and we
are spending it entirely on a word nobody searches for except the five people
who already know us. That is also why the one query we win is the brand
query — `budgetify` is an exact token match against a tiny competitive set, and
it tells us nothing about category visibility.

So the ranking is not being withheld from us for lack of scale. **We are not
competing for these queries at all**, and a same-size app proves the seat is
available.

## What to change, highest leverage first

### 1. Title, short description, full description → [`en-IN.md`](en-IN.md)

Ready to paste. `Budgetify` stays the leading token so the brand rank is
preserved; `Expense Tracker` claims the category's highest-volume head phrase.

| | Now | Proposed |
|---|---|---|
| Title | `Budgetify` (10/30) | `Budgetify: Expense Tracker` (26/30) |
| Short desc | 63/80, no `money manager`, no `UPI` | 74/80, adds `budget tracker`, `money manager`, `UPI` |
| Full desc | stale at ~v1.30, claims 4 languages | current at v1.69, 6 languages, covers `budget planner` / `expense manager` / `spending tracker` |

This also defends the brand query. A competitor is already shipping as
**"Budgetify: Money Manager"** — it currently sits below us, but it has the
keyword advantage on every category term, and a listing called plain
`Budgetify` has nothing but the exact-match to hold that position with.

### 2. Localized store listings → [`localized.md`](localized.md)

The app has shipped in six languages since v1.30, but the **store listing exists
only in English**. Play indexes each locale separately, so Hindi, Marathi,
Bengali, Telugu and Tamil queries are contested by almost nobody — and we
already have the translated vocabulary in `lib/l10n/app_strings.dart`. Five
complete listings are drafted and within limits. **Have a native speaker read
each before publishing.**

### 3. Ratings — the gap that metadata cannot close

Zero ratings, and the app has **no in-app review prompt** (`in_app_review` is
not in `pubspec.yaml`). Rating count and value are direct ranking inputs and the
biggest conversion lever on the listing page. Adding a Play In-App Review call —
after a genuine success moment, not on launch — is the highest-value code change
attached to this problem.

### 4. Set expectations on the head terms

`budget tracker` and `expense tracker` are held by apps with 1M–100M installs.
Metadata gets us *indexed* for them; it will not get us onto page one while we
have 5 installs. The realistic sequence is: win the long tail first
(`offline expense tracker`, `expense tracker without internet`,
`upi expense tracker`, `sms expense tracker` — all shallow result sets where a
10-install app currently ranks), convert those into installs and ratings, then
climb. Treat rows 1–7 of the tracker as a lagging indicator and rows 8–18 as the
scoreboard.

## Measuring it

```bash
python3 marketing/playstore/listing/validate.py
```

```bash
python3 marketing/playstore/aso_rank.py --compare marketing/playstore/listing/baseline-2026-08-08.json
```

Play re-indexes metadata within a day or two, but rankings take **2–4 weeks** to
settle. Re-run weekly; do not judge the change the morning after publishing, and
do not keep editing the title in between — each edit restarts the clock.

## Sources

- [Google Play ranking factors 2026 — AppTweak](https://www.apptweak.com/en/aso-blog/google-play-ranking-factors)
- [ASO ranking factors 2026 — AppFollow](https://appfollow.io/blog/aso-ranking-factors)
- [Metadata policy — Play Console Help](https://support.google.com/googleplay/android-developer/answer/9898842?hl=en)
- [Best practices for your store listing — Play Console Help](https://support.google.com/googleplay/android-developer/answer/13393723?hl=en)
- [Updated guidance to improve app quality and discovery — Android Developers Blog](https://android-developers.googleblog.com/2021/04/updated-guidance-to-improve-your-app.html)
