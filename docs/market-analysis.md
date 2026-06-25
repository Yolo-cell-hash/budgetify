# Budgetify — Market Analysis & Feature Strategy

_Prepared June 2026 · against v1.9.2 · India-focused_

---

## 1. Executive summary

Budgetify competes in India's **personal expense-tracking** category, where the
defining mechanic is **reading bank transaction SMS** so the user never logs
spending by hand. That category was pioneered by Walnut (now **Axio**) and
**MoneyView**, both of which have since pivoted into **lending businesses** —
the money manager is now a customer-acquisition funnel. A second wave of
SMS-based trackers (**FinArt**, **Mera Kharcha**, **Finny**) has appeared, and
this wave competes on **privacy and on-device processing** — the exact ground
Budgetify already owns.

**Budgetify's structural moat is that privacy is _architectural, not optional_:
the app ships with no `INTERNET` permission, so it is *technically incapable* of
uploading data.** Every rival that advertises privacy does so via a *setting*
("Private Mode") on an app that still has full network access — the user is
asked to trust a toggle. Budgetify asks the user to trust nothing.

Where Budgetify is **ahead** of the field: depth of on-device intelligence
(money coach, Financial Health score, net-worth projection, "You vs Past You"),
a fully offline **split + settlement ledger** (a private Splitwise), real
**gamification**, **encrypted local backups**, **four polished themes**, and
**regional-language** support (Hindi + Marathi). No single Indian competitor
matches this combination offline.

Where Budgetify is **behind** (the actionable gaps): **recurring-payment /
subscription tracking** and **bill-due reminders** — now table stakes that
Axio, MoneyView, FinArt, Mera Kharcha and TimelyBills all advertise. Closing
the recurring-payments gap (see the companion plan) is the single highest-value
addition, because it plugs directly into features Budgetify already has
(Financial Health's "recurring load" pillar, Safe-to-Spend, the money coach).

---

## 2. Our feature inventory (v1.9.2)

A grouped inventory of everything currently shipping, so the comparison below is
grounded in the actual codebase, not the marketing.

### Capture
- Automatic transaction capture from bank SMS — real-time listener **and**
  scheduled background scans (hourly … 24h).
- Regulation-aware parser: ~1,900 curated bank headers, TRAI `-S`/`-T`/`-P`
  routing-suffix handling (drops promos), OTP/statement/failed-payment
  rejection, balance-vs-amount disambiguation.
- Manual entry + cash tracking.
- De-duplication and **deletion tombstones** (a deleted txn never resurrects on
  the next scan).

### Organize
- Smart auto-categorization from merchant keywords.
- Built-in categories + **custom tags with custom emoji**.
- **Reusable classification rules** ("apply to all similar, forever").
- **Self Transfer** and **Investments** excluded from spend totals.
- **Split a transaction** — count only *your share* toward budgets.
- **Settlements** — repayments are neither income nor expense (with a proactive
  "looks like Rohan settling up?" suggestion).

### Understand / Analytics
- Budget gauge with 50/75/90/100% threshold alerts.
- Decongested **category donut** (tiny slices folded into "Other").
- **Daily spend curve** with a budget-pace line.
- Swipeable **month-by-month** history.
- Merchant analytics (top merchants, per-merchant detail).
- Spending calendar / heatmap.
- **Home-screen widget** (MTD spend, budget progress, income, net, top category).

### On-device intelligence
- **Money coach** — category-running-hot, large-transaction outliers, pace-vs-
  typical, guarded by robust median/MAD statistics. Card-only, never nags.
- **Safe-to-Spend** — "₹X/day for the rest of the month", works even without a
  budget (falls back to a typical month).
- **Financial Health Score (0–100)** — savings rate / budget adherence /
  recurring load / net worth, reweighted for missing pillars.
- **Net-worth projection** (1/3/5/10-year horizons).
- **"You vs Past You"** month/quarter reflection.

### Goals, net worth & investments
- **Savings goals** with a fill-up "jar", deadlines, on-track pace, celebrations.
- **Net worth** — assets/liabilities, grouped holdings, snapshots.
- **SIP / RD tracking** — recurring *investment* plans with a manual-confirm
  ledger and reminders (the architectural template for recurring *payments*).

### Splits (offline Splitwise)
- Split an expense / "someone owes me" / "I owe someone".
- Per-person balances, settle-up, WhatsApp-friendly shareable summary.
- People are just names — nothing synced.

### Gamification (opt-in)
- Achievement badges across many ladders with rarity-tiered medallions.
- Earned titles from spending mix, sustained over a window.
- Shareable premium profile (emoji/pixel avatar, headline title, showcased
  badges), streaks, and **streak-reward themes**.

### Privacy & security
- **No `INTERNET` permission** — uploading is impossible by construction.
- **Biometric app lock** (fingerprint/face/PIN).
- **AES-256-GCM encrypted backups** (PBKDF2 passphrase) you store anywhere.
- **Privacy amount** blur.

### Export & portability
- Real Excel `.xlsx` (with summary sheet), CSV, formatted text — filterable by
  date / type / tag / payee.

### Personalization & reach
- **Four full themes**: Light (porcelain), Dark (midnight & gold), Smoky-Ivory,
  Seashell-Mauve (streak-unlocked).
- **Trilingual**: English, हिन्दी, मराठी.

---

## 3. The Indian competitive landscape

| Tier | App | What it is | Data model | Monetisation |
|---|---|---|---|---|
| **Direct (SMS-based)** | **Axio** (ex-Walnut) | The OG SMS tracker; reads 40+ banks/cards, bill reminders, bank balance | Cloud (SMS data uploaded) | **Lending** (Pay Later, loans, FDs); Amazon-acquired |
| | **MoneyView** | SMS auto-track, budgets, bill reminders, bank balance | Cloud | **Lending** (₹5k–₹10L personal loans) |
| | **FinArt** | SMS + notification + email/PDF parsing, bills, **subscription tracking** | Cloud, with opt-in **"Private Mode"** + own-Drive backup | Freemium |
| | **Mera Kharcha** | SMS auto-track, **AI assistant**, **EMI/recurring** reminders | On-device processing | Free |
| | **Finny** | Subscription tracker, privacy-positioned | On-device leaning | Freemium |
| **Hybrid (invest + expense)** | **ET Money** | SMS expense tracking **+** mutual funds/SIPs, insurance, tax, credit score, net worth | Cloud | Distribution (MF/insurance), ₹99/mo premium |
| | **INDmoney** | Net-worth aggregator via **Account Aggregator**, US stocks, MF, cards | Cloud (linked accounts, view access) | Distribution / brokerage |
| **Neobank trackers** | **Jupiter**, **Fi** | Spend analytics inside a neobank account | Cloud (their account required) | Banking / lending |
| **Manual trackers** | **Money Manager** (Realbyte) | Polished manual/double-entry, categories, reports | On-device (optional cloud backup) | Paid pro / ads |
| | **Goodbudget**, **Wallet/Spendee**, **Monefy** | Envelope/manual, some bank sync (intl.) | Cloud sync | Subscription |
| **Bill reminders** | **TimelyBills** | Bill reminders + budgeting tuned to EMIs, rent, OTT, festivals | Cloud | Subscription |
| **Credit-led** | **CRED** | Credit-card bill pay, rewards, card spend analytics | Cloud | Fintech / commerce |

**Reading of the landscape:**
- The two biggest "SMS tracker" brands (**Axio, MoneyView**) have **deprioritised
  budgeting** in favour of lending. Their tracker is the hook, the loan is the
  product. This is Budgetify's clearest wedge: _a money manager that isn't
  trying to sell you a loan._
- The credible **product** competitors today are **FinArt** and **Mera
  Kharcha** — both lean privacy/on-device and both already ship
  **subscription/EMI tracking**, which Budgetify lacks.
- **ET Money / INDmoney** play a different (wealth) game and require cloud +
  account linking; they're a threat only if Budgetify chases investing depth.

---

## 4. Feature comparison matrix

✓ = yes · ◑ = partial / opt-in / via account · ✗ = no

| Capability | **Budgetify** | Axio | MoneyView | FinArt | Mera Kharcha | ET Money | Money Manager |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| SMS auto-capture | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| **No `INTERNET` permission (offline by construction)** | **✓** | ✗ | ✗ | ◑ (toggle) | ◑ | ✗ | ◑ |
| No account / sign-up | ✓ | ✗ | ✗ | ✓ | ✓ | ✗ | ✓ |
| No ads | ✓ | ◑ | ◑ | ◑ | ✓ | ◑ | ✗ |
| No lending upsell | ✓ | ✗ | ✗ | ✓ | ✓ | ◑ | ✓ |
| Manual entry + cash | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Auto-categorisation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| Custom reusable rules | ✓ | ◑ | ◑ | ◑ | ◑ | ✗ | ◑ |
| Budgets + threshold alerts | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Category analytics / donut | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Daily forecast / safe-to-spend | ✓ | ✗ | ◑ | ◑ | ◑ | ✗ | ✗ |
| On-device AI coach / insights | ✓ | ✗ | ◑ | ◑ | ◑ (chat AI) | ◑ | ✗ |
| Financial-health score | ✓ | ✗ | ✗ | ✗ | ✗ | ◑ | ✗ |
| Gamification / streaks | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Savings goals | ✓ | ✗ | ◑ | ◑ | ◑ | ✓ | ◑ |
| Net worth + projection | ✓ | ◑ | ✗ | ✗ | ◑ | ✓ | ✗ |
| Split-expense ledger | ✓ | ◑ (legacy) | ✗ | ✗ | ✗ | ✗ | ✗ |
| Settlements (no false income) | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Recurring / subscription tracking** | **✗ (planned)** | ✓ | ✓ | ✓ | ✓ | ◑ | ✗ |
| **Bill-due reminders** | **✗ (planned)** | ✓ | ✓ | ✓ | ✓ | ◑ | ◑ |
| Bank-balance tracking | ✗ (by choice) | ✓ | ✓ | ✓ | ✓ | ◑ | ✗ |
| Encrypted **local** backup | ✓ | ✗ | ✗ | ◑ (own Drive) | ◑ | ✗ | ◑ |
| Biometric app lock | ✓ | ◑ | ◑ | ✓ | ✓ | ◑ | ✓ |
| Home-screen widget | ✓ | ◑ | ✗ | ◑ | ✗ | ✗ | ✓ |
| Regional languages (Hi/Mr) | ✓ | ✗ | ◑ | ◑ | ✓ | ◑ | ◑ |
| Excel/CSV export | ✓ | ◑ | ◑ | ✓ | ◑ | ✗ | ✓ |
| Platform | Android | Android | Android+iOS | Android+iOS | Android | Android+iOS | Android+iOS |

> _Competitor cells are based on publicly advertised features (June 2026) and may
> vary by version; treat ◑ as "present but conditional/limited". Budgetify cells
> are verified against the codebase._

---

## 5. Where we win / where we're exposed

**Win (defensible):**
1. **Architectural privacy** — no network permission. Unique and verifiable; the
   one claim no cloud competitor can copy without re-architecting.
2. **No lending agenda** — the trust gap left by Axio/MoneyView's pivot.
3. **Depth of on-device intelligence** — coach + health score + projections +
   "You vs Past You" exceed every direct competitor offline.
4. **Offline split + settlement ledger** — a private Splitwise no rival ships.
5. **Craft** — four cohesive themes, gamification, Manrope/glass design, Hi/Mr.

**Exposed (close these):**
1. **No recurring/subscription tracking** — every serious competitor has it. _#1
   gap._ (Plan attached.)
2. **No bill-due reminders** — high India relevance (rent, EMI, credit-card due,
   utilities). Natural second step after recurring.
3. **Android-only** — iOS can't read SMS, but FinArt shows an iOS path via
   email/Apple-Pay/PDF import. A read-only iOS companion is a future option.
4. **Discovery of advanced features** — coach, splits, gamification are powerful
   but buried; competitors surface fewer features more loudly.

---

## 6. Gaps & opportunities — unique features to add

> Bank-account balance tracking is intentionally **excluded** per product
> direction. Everything below leans on the offline-SMS moat rather than fighting
> it. Ranked by impact × fit.

### Tier 1 — closes a competitive gap, leverages existing infrastructure
1. **Recurring payments & subscription tracking** _(plan attached)._ Track
   Netflix/rent/EMI/insurance, surface upcoming & overdue, auto-detect from SMS,
   feed Financial Health's existing "recurring load" pillar and reserve dues in
   Safe-to-Spend. **Highest priority.**
2. **Bill-due reminders from SMS.** Parse "bill generated / total due / min due /
   due date" texts (credit cards, utilities, telecom) into a *date + amount
   reminder* — explicitly a transient reminder, **not** a stored running balance,
   so it respects the no-balance direction. Huge India fit; fully offline.
3. **"Teach the parser" — unparsed-SMS review screen** _(already on the roadmap)._
   Show bank SMS the parser skipped; let the user confirm/correct one, creating a
   local rule. Turns the parser's biggest weakness into a moat — improvement with
   zero data leaving the device.

### Tier 2 — India-specific differentiation
4. **Festival & event budgets.** A short-lived "envelope" for Diwali / weddings /
   travel that sits alongside monthly budgets and auto-tags spend in a window.
   Culturally specific; only TimelyBills gestures at this.
5. **Cash-wallet reconciliation.** India is cash-heavy: match ATM withdrawals to
   logged cash spends and nudge "₹4,000 withdrawn, ₹1,200 logged — where did the
   rest go?" Improves accuracy of an SMS-only picture.
6. **Tax buckets (80C / 80D).** Tag investments/insurance/rent/donations into
   deduction buckets and export an ITR-season summary — entirely on-device. No
   competitor offers private, offline tax-prep tagging.
7. **Refund / chargeback matching.** Net a refund credit against its original
   debit so reversed purchases don't distort spend or inflate income (a natural
   extension of the settlements logic just shipped).

### Tier 3 — depth & delight
8. **Subscription price-increase & duplicate-charge alerts** (once recurring
   exists) — "Spotify went ₹119 → ₹149", "two Swiggy charges 3 min apart".
9. **Household view via backup-merge.** Combine two people's encrypted backups
   into a read-only combined picture — privacy-preserving "family budget" with no
   server (extends the existing merge-on-restore code).
10. **Richer / multiple widget sizes** _(roadmap)_ and a **goal round-up**
    (manual) that sweeps rounding into a savings jar.

---

## 7. Recommended roadmap priority

1. **Recurring payments** (v1.10.0) — the gap that most weakens the comparison
   matrix, and the one with the most existing scaffolding to reuse.
2. **Bill-due reminders** (v1.11.0) — builds on the recurring engine + parser.
3. **Unparsed-SMS "teach" screen** — compounding accuracy moat.
4. **Tax buckets + festival budgets** — India-specific marketing-grade
   differentiators for the festive/ITR seasons.
5. **iOS read-only companion** (exploratory) — only if reach matters more than
   focus.

---

## Sources

- [Best Budgeting Apps in India (2025) — Penypitch](https://penypitch.in/best-budgeting-apps-money-management-apps-in-india/)
- [Best Expense Tracker Apps in India 2026 — MoneyView](https://moneyview.in/insights/best-personal-finance-management-apps-in-india)
- [Expense Tracker Apps That Sync with Indian Banks 2025 — FinGrad](https://joinfingrad.com/blog/expense-tracker-apps-that-sync-with-indian-banks-in-2025/)
- [FinArt — Expense Tracker App India (SMS, UPI, Bills, Budgets)](https://finart.app/expense-tracker-app-india/) · [FinArt FAQ — Privacy/Private Mode](https://finart.app/faq.html)
- [Mera Kharcha — AI-Powered Expense Tracker for India](https://merakharcha.in/)
- [Finny — Privacy-Focused Subscription Trackers (2026)](https://getfinny.app/blog/privacy-focused-subscription-trackers-2026)
- [TimelyBills — Money Manager & Bill Reminders for India](https://www.timelybills.app/blog/the-essential-money-manager-and-expense-tracker-app-for-indian-financial-freedom)
- [9 Best Apps to Track Expenses in India (2026) — Aayush Bhaskar](https://aayushbhaskar.com/best-monthly-expenses-tracking-apps-india/)
- [Budgeting Apps in India: Which Really Work? — BillCut](https://www.billcut.com/blogs/budgeting-apps-india-which-work/)
