# Changelog

All notable changes to Budgetify are documented here. Dates are in
`YYYY-MM-DD`. Everything stays on-device — these features add capability
without adding any network access.

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
