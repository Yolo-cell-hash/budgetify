# Changelog

All notable changes to Budgetify are documented here. Dates are in
`YYYY-MM-DD`. Everything stays on-device — these features add capability
without adding any network access.

## [1.44.0] — 2026-07-24

### Added

- **Tax deductions (Phase 1).** A second, optional label on any transaction —
  its tax-deduction section — next to the spending category. Open a
  transaction → **Tax section** and file it under **80C**, **80CCD(1B)**,
  **80D**, **24(b)**, **HRA** or **80G**; a new **Settings → Data → Tax
  Deductions** screen totals each section for a financial year (Apr–Mar) so
  filing season isn't a scramble to reconstruct a year of insurance, ELSS,
  rent and donations.
  - **Fills toward the legal cap.** 80C/80CCD(1B)/80D/24(b) show a used-vs-cap
    bar and remaining headroom ("₹90,000 of ₹1,50,000 — ₹60,000 left"), so you
    can see before year-end whether investing a little more would still save
    tax. Caps are editable — statutory limits change.
  - **Honest about what it can't sum.** HRA and 80G are shown as *evidence*
    (total rent paid / total donations) with a plain note that the actual
    deductible figure depends on your salary or the charity — never presented
    as a settled deduction.
  - **Regime-aware.** A one-time regime setting (Old / New / Not sure); under
    the new regime — which disallows most of these — the screen shows a short
    explainer instead of buckets, so it never implies savings you can't claim.
  - **Suggests the section for you.** Budgetify recognises common payees —
    LIC and other life insurers → 80C, health insurers → 80D, NPS →
    80CCD(1B) — and offers a one-tap "Looks like Section 80D" chip
    (suggestion only; you always confirm). Tag one and choose **Apply to
    all** to tag every payment to that payee, now and in future.
  - **An organiser, not tax advice.** It totals only what you tag; your CA or
    the tax portal decides what's deductible. A standing disclaimer says so.
  - Fully on-device, included in encrypted backups, no new permissions.
    English/Hindi/Marathi UI (Bengali/Telugu/Tamil follow). *Coming next: a
    filing-season summary export and a Jan–Mar home reminder.*

## [1.22.0] — 2026-07-02

### Added

- **Brand identity everywhere it represents you.** The launcher icon's
  wallet-and-sprout mark is now drawn in-app as crisp vector line art
  (`lib/widgets/brand_logo.dart`) and carried, with the motto — *"The
  private, offline budget tracker that does the work for you."* — across
  every social and exportable surface:
  - **Splash** — the gold brand mark replaces the generic wallet glyph in
    the animated badge, with the motto under the wordmark.
  - **Notifications** — the status-bar icon is now the brand silhouette
    (wallet with clasp cut-out + sprout leaves), white-on-transparent as
    Android requires.
  - **PDF export** — a proper brand header (navy logo tile, wordmark,
    motto, generated date over a gold rule) and a footer on every page
    with the motto and page numbers. Excel and text exports carry the
    motto line too.
  - **Monthly Wrapped** — the shareable card's brand pill now shows the
    real mark instead of a generic sparkle.
  - **Gamified profile card** — footer upgraded to mark + wordmark +
    motto, so shared profiles carry the identity.
  - **Split summaries** — the WhatsApp one-liner is signed "tracked on
    Budgetify, the private offline budget tracker".
  All rendering stays on-device; nothing about the privacy model changes.

## [1.21.0] — 2026-07-02

### Added

- **Import bank statements (CSV / Excel).** Settings → **Import Data** →
  **Bank statement** brings in the history the SMS pipeline can't see —
  months from before Budgetify was installed, an account whose alerts land on
  another phone, or an export from another app. Works with any bank: the
  importer finds the header row under the preamble junk, guesses what each
  column means (HDFC/ICICI/SBI/Axis/Kotak spellings built in), understands
  Indian formats (`1,23,456.78`, `dd-MM-yy`, month-name dates, `Dr`/`Cr`
  markers, ₹/INR prefixes, trailing-minus and bracketed negatives), and asks
  you to confirm the mapping — confirmed once, it's remembered for that bank.
  - **No double counting.** Rows matching the amount and date (±1 day) of a
    transaction already on the device — usually the SMS copy of the same
    spend — are flagged as probable duplicates and excluded unless you tick
    them back in, with a note showing when SMS tracking began. Re-importing
    the same file is a no-op, and a deleted imported row stays deleted.
  - **Lands organised.** Payees are extracted from statement narrations
    (`UPI-SWIGGY LIMITED-…` → *Swiggy Limited*), the merchant-keyword table
    auto-categorises what it recognises, and your saved auto-tag rules run
    over the newcomers immediately.
  - **Balances ignored by design.** The balance column is recognised so
    detection works, but its values are never read or stored.
  - Old `.xls` and PDF statements are politely declined with guidance (PDF
    import is planned). Everything is parsed on-device from a file you pick —
    no new permissions, still no INTERNET. Localised in EN/HI/MR/BN.

## [1.10.0] — 2026-06-25

### Added

- **Recurring payments.** Track the money that goes out on a schedule —
  subscriptions (Netflix, Prime), rent, EMIs, insurance premiums, utilities,
  gym — and stop being surprised by it. Add a plan with an amount (or mark it
  **"amount varies"** for bills like electricity), a cadence (**weekly /
  monthly / quarterly / yearly**), a next-due date and an optional end date.
  - **See what's coming.** A new **Recurring Payments** screen (Settings → Data,
    or the bell from a reminder) lists everything by urgency — overdue first,
    then due-today, then upcoming — with one-tap **Mark paid** / **Skip**. A
    **Home card** surfaces the next bills due (overdue highlighted) and hides
    itself entirely if you track none.
  - **Auto-detect from SMS.** Budgetify links a matching bank-SMS debit to the
    cycle it pays (a ⚡ marks auto-detected ones) and can **suggest** recurring
    charges it spots in your history — suggestion only, never auto-created. A
    predicted bill is never counted as spend; only the real debit is, exactly
    once.
  - **Reminders.** A **Bill reminder** notification with **Paid / Skip** buttons
    fires before each due date (your choice of lead time) and again if it goes
    overdue — resolved straight from the notification, even in the background.
  - **It feeds the rest of the app.** Fixed-amount plans count toward Financial
    Health's **recurring-load** pillar, and **Safe-to-Spend** now reserves the
    bills you still have to pay this month, so "₹X/day safe" already sets aside
    the rent and EMIs.
  - **Track as recurring** from any transaction (pre-fills name, amount,
    category and day). Fully on-device, in all four themes, localised (EN/HI/MR),
    and included in encrypted backups.

## [1.9.2] — 2026-06-25

### Added

- **Settlements — repayments no longer count as income.** When you cover a
  group bill and friends pay you back, those incoming payments were being
  counted as income (inflating your savings rate and Financial Health). Open
  any transaction → **"This is a settlement"** and it's excluded from **both**
  income and spending — the same neutral treatment as Self Transfer. Optionally
  pick **who** paid you back to also clear their balance in the split ledger
  (settle-up). And when an incoming payment matches an outstanding debt,
  Budgetify proactively suggests *"Looks like Rohan settling up — mark as
  settlement?"* (suggestion only; real income is never reclassified for you).
  Works both ways — repaying a debt you owe also stays out of your spending.
  On-device, all four themes, localised (EN/HI/MR).

## [1.9.1] — 2026-06-25

### Added

- **Split a transaction.** Open any spend and tap **Split this transaction** to
  count only **your share** toward your budgets — no more deleting and
  re-entering when you pay for the group. Set your share directly or use the
  **quick equal-split** (÷2 / ÷3 / ÷4 / ÷5), and see live exactly what counts.
  Optionally flip on **"Track who owes you"** to record the rest in the split
  ledger so you can settle up later. A split transaction shows **your share as
  the headline** (with the full amount struck through) and a **Split** badge,
  and carries a "÷ your share" tag in transaction lists. Budgets, category
  budgets, the spending curve, the money coach and Financial Health all update
  instantly. Fully on-device, in all four themes, and localised (EN/HI/MR).

## [1.9.0] — 2026-06-22

### Added

- **Net worth projection.** The Net Worth screen now shows where your wealth is
  headed: pick a horizon (1/3/5/10 years) and optionally assume ~8% yearly
  growth, and see the projected figure plus "you'd reach ₹X in about Y years."
  Projects from your **typical monthly savings** (median of recent completed
  months) — an on-device estimate, clearly labelled, never financial advice.
- **You vs Past You.** A reflection card on the Insights screen comparing your
  most recent completed **month** (or **quarter**) with the one before —
  spending, income, savings and savings rate, each with a good/bad delta and a
  one-line verdict. Compares completed periods only, so it never pits a partial
  month against a full one.
- **Hindi language toggle.** Settings → Appearance → **Language** switches the
  app between English and हिन्दी, applied instantly and remembered. Built on a
  lightweight string table + `LocaleProvider`; navigation, the Appearance
  settings and the two new cards are translated, with more surfaces to follow.

## [1.8.0] — 2026-06-22

### Added

- **Streak-reward themes.** Two new app themes, unlocked by your daily streak and
  visualised on a new **Streak Reward Road**:
  - **Smoky Blue & Warm Ivory** — unlocked at a **3-day streak**.
  - **Soft Seashell & Dusty Mauve** — unlocked at a **7-day streak**.
  Both are full themes (background, cards, accents and text all recolour), joining
  the existing Light and Dark. Pick a theme from **Settings → Appearance**, where
  locked themes show how far away they are; tap **Streak Rewards** there (or the
  **Streaks** tab in the Rewards hub) to see the road and apply a theme. Unlocks
  are based on your **best** streak, so an earned theme never re-locks if a streak
  breaks. The road is built to grow as more streak rewards arrive.

## [1.7.0] — 2026-06-20

### Added

- **Savings Goals.** Set discrete targets ("Goa trip ₹40k by December"), each
  shown as a **savings jar** that fills as you contribute. Record contributions
  manually (amount + date); set an optional deadline and see a "₹X/month to stay
  on track" figure; edit, complete or delete. A **Goals card on Home** surfaces
  your top jars. When a goal is reached you get an in-app **celebration** and a
  **notification** — and completing goals unlocks the new **Goal Getter** trophy
  in Gamified Budgets. All on-device and **included in encrypted backups**.

## [1.6.3] — 2026-06-20

### Changed

- **Premium trophy frames.** Badges now use a consistent hexagonal shield +
  crown (Clash-Royale-mastery style) whose **metal colour and ornamentation**
  (crown gems, side ears, glow) escalate by tier — the icon stays the same,
  only the frame changes. Replaces the earlier per-tier star/octagon shapes.
- **Title progress bars.** Every title shows a live bar toward its goal (e.g.
  2 / 6 months). The rule is now "meet the threshold in N qualifying months" —
  not an average — and tapping a title shows its full requirement + progress.
- **Broke Spender** now needs 90 no-spend days (up from 60).
- **More pixel avatars** — 12 distinct male & female characters (added bob,
  mohawk and top-knot styles, plus more skin tones).
- **Investments grouped by type** on Net Worth — Fixed Deposits, Recurring
  Deposits, Mutual Funds, etc. are clubbed together under headers.

## [1.6.2] — 2026-06-20

### Changed

- **Gamified titles are clearer.** Tapping any title — earned or locked — opens
  a sheet with its **full requirement, including the time window** (e.g. "35%+
  of income on Food & Dining, averaged over the last 6 months"), so locked
  titles are no longer cryptic. Earned titles can be featured from there.
- **Better pixel avatars.** A set of **distinct male & female characters**
  (varied hair, headwear and skin tones) instead of recolours of one sprite.
  The accent picker no longer applies to pixel avatars (they carry their own
  colours).

## [1.6.1] — 2026-06-20

### Changed

- **Gamified Budgets polish.** Trophies now change **shape by rarity**
  (circle → hexagon → octagon → star) so higher tiers feel distinctly premium.
  Avatars are now real **pixel characters** (recoloured chibi sprites) instead
  of abstract art. **Titles** have a dedicated gallery on the profile (earned +
  locked, like trophies) and now appear on the shareable card. The **shareable
  card** is richer — a stats strip (streak · trophies · titles), earned-title
  chips, and labelled trophies. Featured badges on the card are capped at 4.

## [1.6.0] — 2026-06-20

### Added

- **Gamified Budgets (opt-in).** A separate, reward-driven layer you switch on
  from Settings → Intelligence. When off, the app is exactly as before — no nav
  or dashboard changes.
  - **Achievement badges** across many ladders — daily streak, money tracked,
    transactions, time tracked, fully-tagged months, Budget Hero, Super Saver,
    net worth, debt-free, no-spend days and category explorer — with
    rarity-tiered medallions (copper → diamond), animated flourishes, live
    progress to the next tier, and an "Achievement Unlocked!" moment.
  - **Earned titles** from your spending mix (Foodie, Bill Master, Investor,
    Money Magnet, …), earned over a sustained window — never given by default.
  - **A premium, shareable profile** — choose an emoji or procedural pixel
    avatar and accent, a username, a headline title, and up to five showcased
    badges, then share it as an image. Opened from a new avatar in the Home
    header.
  - Everything is computed on-device and **included in encrypted backups**, so
    your profile, streak and unlocks are never lost.

## [1.5.2] — 2026-06-19

### Added

- **Financial Health display toggle.** A new *Detailed Financial Health* switch
  under Settings → Intelligence. Off by default: only a compact score (e.g.
  `72/100`) shows on the balance card under your savings rate, keeping the
  dashboard uncluttered. Turn it on for the full breakdown card with the gauge
  and per-pillar detail. The ⓘ explainer is reachable from both views.

### Fixed

- **Financial Health refreshes live.** Editing a budget, a holding, or a
  recurring plan now updates the score immediately, instead of only after
  reopening the app from cold.
- **Correct version in Settings.** Settings → About now shows the real app
  version (it had been stuck at 1.4.0) and is driven from a single constant so
  it can't drift again.

## [1.5.1] — 2026-06-19

### Added

- **Financial Health Score.** A single 0–100 number on the home screen, right
  under your savings rate, giving an at-a-glance read on your money health
  (100 is excellent, 0 is poor). It blends up to four pillars — **savings rate**
  (35%), **budget adherence** (25%), **recurring load** (20%) and **net worth**
  (20%) — into an animated gauge with a per-pillar breakdown. Pillars without
  data yet (no budget set, no holdings) are skipped and the rest reweighted, so
  the score always reflects what's available. A tap on the ⓘ explains exactly
  how it's calculated. Computed entirely on-device.

## [1.5.0] — 2026-06-19

The biggest update yet: a private on-device money coach, a clearer
safe-to-spend, and a fully offline split ledger.

### Added

- **On-device money coach.** Proactive, private spending nudges computed
  entirely on your phone:
  - **Category running hot** — a category that's meaningfully above your own
    pace for this point in the month (compared day-for-day against prior
    months, so it's fair early in the month).
  - **Large transaction** — a single spend that's a real outlier versus your
    usual amount in that category.
  - **Pace vs your typical month** — a heads-up when you're tracking above (or
    comfortably below) your normal spend.
  - Heavily guarded against false alarms (robust median/MAD statistics, dual
    percentage-and-rupee thresholds, minimum history, absolute floors), and
    card-only so it never interrupts you. Available under AI Prediction Mode.
- **Safe-to-spend.** A clear "₹X/day safe to spend for the rest of the month"
  figure that now **works even without a budget** — it falls back to your
  typical month. Includes a spent-vs-pace bar, an honest "vs budget / vs
  typical" label, and over-target messaging.
- **Offline split ledger ("Splits").** Track shared expenses and who owes
  whom, entirely on your device — a Splitwise that never leaves your phone.
  - Three clear actions: **Split an expense**, **Someone owes me** (expect
    incoming cash), and **I owe someone**.
  - A live result line spells out exactly who ends up owing whom.
  - Per-person view with a balance, **settle-up**, and a shareable
    WhatsApp-friendly summary.
  - **My-share accounting:** when you pay for a group and link the split to a
    transaction, only your own share counts toward your spending totals.
  - Equal or exact splits with live reconciliation; people are just names —
    no accounts, nothing synced.

### Changed

- The **Insights** screen now leads with the safe-to-spend card; the forecast
  hero focuses on the month-end projection.
- **Premium ledger UI:** champagne-gold/initials avatars (no emoji), people-list
  rows now show the latest shared expense as a subtitle, and a clearer
  *Paid by / Split between* editor.

### Fixed

- **Restore now refreshes the dashboard.** Classified/unclassified counts and
  totals update immediately after restoring a backup — no manual scan needed.
- **Calmer scan errors.** A manual SMS scan no longer surfaces a raw platform
  error when the device's SMS provider returns a malformed message; it shows a
  brief message and still refreshes your data.
- Corrected a bias in the month-over-month insight that could make every
  category read as "down" early in the month.

## [1.4.1]

### Fixed

- Notification small icon rendered as a solid square on some devices; now uses
  a dedicated white-on-transparent status icon.
- Hardened startup so a notification-subsystem hiccup can never block the app
  from opening.

[1.7.0]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.7.0
[1.6.3]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.3
[1.6.2]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.2
[1.6.1]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.1
[1.6.0]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.6.0
[1.5.2]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.5.2
[1.5.1]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.5.1
[1.5.0]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.5.0
[1.4.1]: https://github.com/Yolo-cell-hash/budgetify/releases/tag/v1.4.1
