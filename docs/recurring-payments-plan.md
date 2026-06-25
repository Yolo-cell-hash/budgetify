# Recurring Payments — Implementation Plan

_Target: v1.10.0 · fully on-device · 4 themes · EN/HI/MR · in encrypted backups_

---

## 0. Goal & guardrails

Let users track recurring **expenses** — subscriptions (Netflix, Prime,
Spotify), rent, EMIs, insurance premiums, utilities, gym, school fees — so that:

- upcoming and overdue dues are visible at a glance,
- the app can **auto-detect** a recurring debit from SMS and offer to track it,
- dues feed the features we **already have** (Financial Health's "recurring
  load" pillar, Safe-to-Spend, the money coach), and
- the user gets a timely reminder before each due date.

**Guardrails**
- **Offline only** — no new permissions; detection runs inside the existing
  background scan; nothing leaves the device.
- **Never invent spend.** A *predicted/upcoming* charge is **not** counted as an
  expense. Only the realised SMS transaction counts (exactly once), so budgets
  and totals are never double-counted.
- **Suggestion, not automation.** Like settlements, auto-detection only
  *proposes* a plan; the user confirms.
- **Not bank-balance.** This feature tracks *commitments* (amount + due date),
  not a running account balance.

### Reuse the SIP engine

This is deliberately the **expense twin of SIP/RD tracking**. The existing
[`Sip`](../lib/models/sip.dart) / `SipPayment` model, [`SipService`](../lib/services/sip_service.dart),
its DB tables, reminder dedup, and Financial-Health hook are the template — copy
the proven shape, swap "invest into a holding" for "pay a bill". Where possible,
**generalise the SIP schedule math** rather than duplicating it.

---

## 1. Data model — `lib/models/recurring_payment.dart`

Mirror the plan + ledger split that SIP uses (`Sip` = plan, `SipPayment` =
resolved instalment).

```dart
enum RecurringCadence { weekly, monthly, quarterly, yearly }

enum RecurringStatus {
  upcoming,   // due in the future, not yet resolved
  detected,   // auto-matched to an SMS debit
  paid,       // user confirmed
  skipped,    // user said "not this period"
  missed,     // past due, never resolved
}

/// A recurring expense plan.
class RecurringPayment {
  final int? id;
  final String name;            // "Netflix", "Flat rent"
  final String category;        // maps to an ExpenseCategories value
  final double? amount;         // null when amountIsFixed == false (e.g. electricity)
  final bool amountIsFixed;
  final RecurringCadence cadence;
  final int dayOfMonth;         // anchor day (clamped per month, like Sip)
  final DateTime? startDate;
  final DateTime? endDate;      // optional; open-ended subscriptions have none
  final bool autoMatch;         // watch SMS for a matching debit
  final String? matchHint;      // normalised merchant/sender keyword for matching
  final bool reminderEnabled;
  final int reminderLeadDays;   // remind N days before due (default 2)
  final bool paused;
  final String? lastReminderPeriod; // 'YYYY-MM[:slot]' dedup, like Sip
  final DateTime createdAt;
  // + fromMap/toMap/copyWith, identical style to Sip.
}

/// One resolved occurrence of a plan (the ledger row).
class RecurringCharge {
  final int? id;
  final int planId;
  final String periodKey;       // 'YYYY-MM' (or 'YYYY-Www' for weekly) — unique per (plan, period)
  final DateTime dueDate;
  final double amount;
  final RecurringStatus status;
  final int? transactionId;     // the matched SMS transaction, when detected/paid
  final DateTime? resolvedAt;
}
```

**Schedule math:** lift the pure helpers from `Sip` (`daysInMonth`,
`dueDateInMonth`, `nextDueOnOrAfter`, `periodKeyFor`, `_countDueDates`) into a
shared `RecurrenceSchedule` mixin/util that takes a `cadence`, so `weekly`
/`quarterly`/`yearly` reuse one tested implementation. Keep all of it I/O-free so
it's unit-tested directly (as `sip.dart` is).

---

## 2. Database — `lib/services/database_service.dart`

Bump `version: 18 → 19` and add two tables, mirroring `sips` / `sip_payments`
(both as `CREATE TABLE IF NOT EXISTS` in `_onCreate`, **and** created in
`_onUpgrade` under `if (oldVersion < 19)`).

```sql
CREATE TABLE IF NOT EXISTS recurring_payments(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL,
  amount_is_fixed INTEGER NOT NULL DEFAULT 1,
  cadence TEXT NOT NULL DEFAULT 'monthly',
  day_of_month INTEGER NOT NULL DEFAULT 1,
  start_date INTEGER,
  end_date INTEGER,
  auto_match INTEGER NOT NULL DEFAULT 1,
  match_hint TEXT,
  reminder_enabled INTEGER NOT NULL DEFAULT 1,
  reminder_lead_days INTEGER NOT NULL DEFAULT 2,
  paused INTEGER NOT NULL DEFAULT 0,
  last_reminder_period TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS recurring_charges(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  period_key TEXT NOT NULL,
  due_date INTEGER NOT NULL,
  amount REAL NOT NULL,
  status TEXT NOT NULL,
  transaction_id INTEGER,
  resolved_at INTEGER,
  UNIQUE(plan_id, period_key)
);
```

**DAO methods** (same naming style as the SIP DAOs):
`insertRecurringPayment`, `updateRecurringPayment`, `deleteRecurringPayment`,
`getRecurringPayments`, `getRecurringPayment(id)`, `getRecurringChargeForPeriod`,
`upsertRecurringCharge`, `getActiveRecurringPayments({DateTime month})`,
`getRecurringMonthlyCommitment()`.

---

## 3. Service — `lib/services/recurring_service.dart`

Stateless & context-free (so it runs in the background isolate), exactly like
`SipService`.

Responsibilities:
- `upcoming({int withinDays = 14})`, `overdue()`, `dueOn(date)` — derived from
  plans + the charge ledger.
- `markPaid(plan, period, {double? amount, int? transactionId})`,
  `skip(plan, period)` — write a `RecurringCharge` (idempotent per period, copy
  `SipService`'s "already resolved? bail" pattern).
- `monthlyCommitment()` — Σ active, fixed-amount, non-paused plans for *this*
  month. Used by Financial Health and Safe-to-Spend.
- `sendDuePrompts({required bool evening})` — reminders via `NotificationService`
  with **Paid / Skip** actions; dedup via `lastReminderPeriod` (lift the
  noon/evening slot logic verbatim from `SipService.sendDuePrompts`). Honour
  `reminderLeadDays` so the nudge can fire *before* the due date, not only on it.
- `resolveFromAction(planId, period, didPay)` — background-safe resolver for the
  notification buttons (mirror `SipService.resolveFromAction`).
- **Auto-detect** (Phase 2):
  - `detectCandidates()` — group historical debits by normalised merchant,
    find a ~regular cadence with a stable amount using the **same robust
    median/MAD statistics** already in [`CoachService`](../lib/services/coach_service.dart);
    return suggestions (never auto-create).
  - `tryMatch(transaction)` — when a new debit matches an active plan's
    `matchHint` + amount window + due window, resolve that period's charge as
    `detected` and link `transactionId`.

---

## 4. SMS pipeline hook

In the save path (`sms_service.dart` / `background_service.dart`), after a debit
is persisted and rules are applied, call `RecurringService.tryMatch(txn)` — the
same insertion point where settlement suggestions are raised today. On-device,
no UI in the background path.

---

## 5. Integrations with existing features

| Surface | Change |
|---|---|
| **Financial Health** ([`financial_health_service.dart`](../lib/services/financial_health_service.dart)) | The "recurring load" pillar currently sums **only SIP/RD** plans. Add `RecurringService.monthlyCommitment()` to `recurringMonthly`. _One-line conceptual change; pillar maths already exist._ |
| **Safe-to-Spend** (`insights_service` / `safe_to_spend_card`) | **Reserve** not-yet-paid dues for the rest of this month so "₹X/day safe" subtracts the rent/EMI you haven't paid yet. High-value UX win. |
| **Home** | New `widgets/upcoming_recurring_card.dart` — next N dues, overdue highlighted, tap → recurring screen. |
| **Money coach** (optional) | Card: "₹X in bills due over the next 5 days." |
| **Budgets** | No double-count: predicted charges never count; the realised, categorised transaction flows through budgets normally. |

---

## 6. UI (all via `AppColors.of(context)` / `HeroStyle` → 4 themes for free)

- **`screens/recurring_screen.dart`** — tabs **Upcoming · All · Paused**; rows
  show name, amount, due-in/overdue chip (themed `danger`/`accent`/`success`),
  cadence. Reuse `TransactionCard`-style premium rows and the existing
  swipe/`AppDialog` patterns.
- **`widgets/recurring_editor_sheet.dart`** — add/edit a plan (name, category,
  amount + "amount varies" toggle, cadence, due day, start/end, reminder lead,
  auto-match). Mirror `goal_editor_sheet.dart` / `holding_editor_sheet.dart`.
- **`screens/recurring_detail_screen.dart`** — the per-plan charge ledger with
  Paid/Skip actions and history.
- **Entry points:** a **"Track as recurring"** action on
  `transaction_detail_screen.dart` (pre-fills name/amount/category/day from the
  txn — the lowest-friction creation path), plus a Home card and a
  Settings → Intelligence toggle to enable the feature.

---

## 7. Notifications — `lib/services/notification_service.dart`

Add a **"Bill reminders"** channel. Reuse the SIP prompt plumbing
(`showSipPrompt` → `showRecurringPrompt`) with **Paid / Skip** actions routed to
`RecurringService.resolveFromAction` from the background isolate. Schedule on the
existing WorkManager daily slots already used for SIP prompts (no new scheduler);
fire at `dueDate − reminderLeadDays`, again on the due day, and an overdue nudge.

---

## 8. Backup — `lib/services/backup_service.dart`

Add `recurring_payments` + `recurring_charges` to the JSON snapshot, the restore
merge, and `BackupCounts` (extend the `sips`/`goals` count fields and the
`total` getter). Restore must be idempotent (`UNIQUE(plan_id, period_key)` makes
charge re-insert safe).

---

## 9. Localization — `lib/l10n/app_strings.dart`

Add members using the existing `_t(en, hi, mr)` pattern: screen/tab titles,
cadence names, status labels, editor fields, reminder copy ("₹{x} to {name} due
in {n} days", "Mark paid", "Skip this month", "Overdue"). English first; Hi/Mr
alongside, consistent with how settlements/splits were localised.

---

## 10. Tests — `test/`

- `recurring_schedule_test.dart` — pure cadence math (next-due, period keys,
  month-length clamping, weekly/quarterly/yearly), mirroring the SIP schedule
  tests.
- `recurring_detect_test.dart` — detection heuristic flags a stable monthly
  series and rejects irregular/one-off spends (model on `coach_service_test.dart`).
- Extend `financial_health_test.dart` — recurring pillar includes plans.
- Safe-to-Spend reservation test.

---

## 11. Edge cases & guardrails

- **Variable-amount bills** (`amountIsFixed = false`): don't add a fixed figure
  to Financial Health; reminders/estimates use the **last realised amount**.
- **Double-count protection:** predicted charges are never spend; one SMS
  resolves **at most one** plan's current-period charge.
- **Paused / ended plans** are excluded from dues and from `monthlyCommitment`.
- **Annual/quarterly** cadences (insurance, domains) handled by the cadence enum.
- **No new permissions**; detection piggybacks on the existing background scan.

---

## 12. Phasing

| Phase | Scope | Version |
|---|---|---|
| **1 — MVP** | Manual plans (monthly), Upcoming/Overdue list, due reminders, Financial-Health + Safe-to-Spend wiring, Home card, backup, l10n, schedule tests | **v1.10.0** |
| **2 — Smart** | SMS auto-detect *suggestions*, auto-resolve matched charges, "Track as recurring" from a transaction | v1.10.x |
| **3 — Depth** | Weekly/quarterly/yearly cadences, variable-amount estimation, subscription **price-increase** & duplicate-charge alerts | v1.11.0 |

---

## 13. File touch list (quick reference)

**New**
- `lib/models/recurring_payment.dart`
- `lib/services/recurring_service.dart`
- `lib/screens/recurring_screen.dart`
- `lib/screens/recurring_detail_screen.dart`
- `lib/widgets/recurring_editor_sheet.dart`
- `lib/widgets/upcoming_recurring_card.dart`
- `test/recurring_schedule_test.dart`, `test/recurring_detect_test.dart`

**Modified**
- `lib/services/database_service.dart` (v19 + tables + DAOs)
- `lib/services/financial_health_service.dart` (recurring pillar source)
- `lib/services/insights_service.dart` (+ safe-to-spend reservation)
- `lib/services/notification_service.dart` (bill channel + Paid/Skip)
- `lib/services/sms_service.dart` / `background_service.dart` (`tryMatch` hook)
- `lib/services/backup_service.dart` (snapshot + counts + restore)
- `lib/screens/home_screen.dart` (+ upcoming card)
- `lib/screens/transaction_detail_screen.dart` ("Track as recurring")
- `lib/screens/settings_screen.dart` (enable toggle)
- `lib/l10n/app_strings.dart` (EN/HI/MR strings)
