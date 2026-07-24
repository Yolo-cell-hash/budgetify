# Tax Buckets — Implementation Plan

_Draft · branch `claude/tax-buckets` (off main `28d81db`) · India-focused_

## Why

Every filing season, Indian taxpayers reconstruct a year of deductible spends —
insurance, ELSS/PPF, rent, donations, tuition, education-loan interest — from
scattered statements. Budgetify already captured every one of those
transactions; it just never labelled them by tax section. Tax buckets add that
label as a **second, orthogonal axis** on a transaction, total each section
against its statutory cap, and export a filing-ready summary.

Uniquely a fit for this app: tax data (income, insurance, rent, donations,
investments) is the most sensitive financial data a person holds. Budgetify is
*architecturally incapable* of uploading it (no `INTERNET`). "Organise your
deductions on a phone that cannot phone home" is a claim no cloud tax app
(ClearTax et al.) can make.

## Hard scope boundaries (read first)

1. **Record-keeper, never a tax advisor.** The feature tags and totals what the
   *user* marks. It must never compute tax liability, recommend a regime, or
   assert that an amount "is deductible." Same framing already used on
   net-worth projection (*"an estimate, never financial advice"*), applied
   harder because tax is legally consequential. A prominent disclaimer ships on
   the Tax screen and every export.
2. **No bank balance.** Unchanged product no-go. Nothing here reads or stores a
   running balance; it sums transactions the user tagged.
3. **No notification reader.** Out of scope for this work entirely.
4. **Offline, on-device, no new permissions.** New DB column + prefs + one
   export template. Rides the existing encrypted backup.

## The old-regime / new-regime reality

Since FY 2023-24 the **new tax regime is the default**, and it disallows almost
all of these deductions (80C, 80D, HRA, …). So this feature primarily serves
**old-regime filers** (still a real segment — big home-loan / HRA / maxed-80C
households). The app must not imply savings that don't exist:

- A one-time **regime setting**: *Old · New · Not sure* (default *Not sure*).
- **New regime** → the Tax screen shows a single honest card explaining most
  deductions don't apply under the new regime, and offers a link to switch the
  setting. No buckets, no totals, no nudges.
- **Old / Not sure** → full feature.

This gate is the difference between "useful and honest" and "misleading."

## Data model

### Transaction: one new nullable column

A transaction already has one `category` (its spending kind). A tax bucket is a
*different* dimension — a ₹12,000 LIC payment is category **Insurance** *and*
tax bucket **80D**. So this is a new field, not a reuse of `category`.

- `transactions.tax_bucket TEXT` (nullable) — stores a stable bucket id
  (`'80C'`, `'80D'`, `'80CCD1B'`, `'HRA'`, …), or null (the norm — most
  transactions have none).
- `TransactionModel` gains `final String? taxBucket;` threaded through the
  constructor, `fromMap`/`toMap`, `copyWith`, and a `clearedTaxBucket()` helper
  (copyWith can't null a field, mirroring the existing `untagged()` /
  `confirmedReview()` pattern).
- **Migration v24 → v25**: `ALTER TABLE transactions ADD COLUMN tax_bucket TEXT`.
  Additive, nullable, no backfill — every existing row simply has no bucket.

### Bucket catalog (a Dart model, the `plus_products.dart` pattern)

`lib/models/tax_bucket.dart` — the single source of truth, no magic strings:

```
enum TaxBucketKind { cappedDeduction, evidenceOnly }

class TaxBucket {
  final String id;            // '80C'         (immutable, persisted)
  final String section;       // 'Section 80C'
  final String shortLabel;    // 'Investments & insurance'
  final TaxBucketKind kind;
  final int? defaultCapInr;   // 150000, or null for evidence-only
  // localized label/help resolved via AppStrings, not stored here
}
```

**Two kinds, because honesty requires it:**

- **cappedDeduction** — a flat statutory ceiling the app can sum against:
  | id | Section | Default cap |
  |---|---|---|
  | `80C` | 80C (ELSS, PPF, LIC, tuition, home-loan principal…) | ₹1,50,000 |
  | `80CCD1B` | 80CCD(1B) — NPS, over 80C | ₹50,000 |
  | `80D` | 80D — health insurance | ₹25,000 / ₹50,000¹ |
  | `80E` | 80E — education-loan interest | no cap |
  | `24B` | 24(b) — home-loan interest | ₹2,00,000 |

- **evidenceOnly** — the deductible figure is *not* the sum of payments, so the
  app must NOT present the total as the deduction; it organises evidence only:
  | id | Section | Why evidence-only |
  |---|---|---|
  | `HRA` | HRA / 80GG — rent paid | Exemption = least of three formulas involving salary the app doesn't hold |
  | `80G` | 80G — donations | 50% vs 100% (and qualifying limits) vary per donee |

  These show "total rent paid: ₹X — your employer/CA computes the HRA
  exemption" rather than a filled-vs-cap bar.

  ¹ 80D's cap depends on senior-citizen status; ship ₹25,000 default, editable.

**Caps are editable and dated.** Statutory limits change most budgets. Store
user overrides in prefs (`tax_caps` map, keyed by bucket id) and show the
active cap with a "defaults as of FY2025-26 — tap to edit" note. Never
hard-code-and-forget.

### Auto-suggest rules (mirror the category-rules engine)

A dedicated lightweight table, orthogonal to category rules (a merchant can
carry both a category rule *and* a tax rule independently):

- `tax_bucket_rules(id, payee TEXT, bucket TEXT, is_active INTEGER, created_at)`
  — "every payment to *LIC* → suggest 80C." Same normalise-and-match logic as
  `TransactionRule`, same "apply to all similar, forever" gesture.
- Seed a built-in keyword map for obvious payees (LIC/HDFC Life → 80C or 80D
  prompt, NPS → 80CCD1B, an education-loan servicer → 80E, a recurring landlord
  payee → HRA). **Suggestion only** — never auto-applied, because a wrong tax
  tag is worse than an untagged one.

## How it plugs into what exists

| Piece | Reuse |
|---|---|
| Tagging gesture | The transaction-detail category UI — add a compact "Tax section" row below it |
| Auto-suggest | The `findMatchingRule` / apply-to-all mechanic, on the new rule table |
| Totals | A new `sumByTaxBucket(fyStart, fyEnd)` query on `DatabaseService`, indexed on `tax_bucket` |
| Export | `ExportService.buildExport` gains a `taxSummary` mode + brand header/footer already in place |
| Backup | New column rides transaction backup automatically; add `tax_caps` + `tax_regime` to the backup prefs payload |
| Localization | `AppStrings` — six languages, per convention |

## Financial-year handling

Indian FY = **1 Apr – 31 Mar**, not the calendar year. The Tax screen carries an
**FY selector** (default: current FY). All totals, the export, and the caps are
scoped to the selected FY window. A `FinancialYear` helper computes the window
from a date so this logic lives in one place.

## UI surfaces

1. **Transaction detail** — a new "Tax section" row under Category: unset by
   default; tapping opens a bucket picker (with the auto-suggested bucket, if
   any, pre-highlighted and an "apply to all from *LIC*" toggle).
2. **Tax screen** (new, reachable from Settings → Data, or a Home card in
   Jan–Mar) —
   - FY selector,
   - per capped-bucket: a filled-vs-cap bar ("80C: ₹90,000 of ₹1,50,000 —
     ₹60,000 headroom"),
   - per evidence-only bucket: the total with its honest caption,
   - the standing **"organiser, not tax advice"** disclaimer,
   - an **Export Tax Summary** button.
3. **Settings** — the regime setting + cap editor live here.

## Export: "Tax Summary FY2025-26"

A new `ExportFormat`-adjacent mode on `ExportService`: grouped by bucket, each
with its contributing transactions (date, payee, amount), a per-bucket subtotal,
capped buckets showing used/cap, evidence-only buckets flagged as such, and the
disclaimer in the footer. PDF (hand to a CA) and Excel (transcribe to the ITR
portal). Reuses the existing brand header/footer and per-section table layout.

## No-regression guarantees

- Feature is **inert when unused**: the new column is nullable and read only by
  the Tax screen and the tax-summary export; the transaction list, budgets,
  Financial Health, coach, and every existing total ignore `tax_bucket`
  entirely. A user who never opens the Tax screen sees zero change.
- `SmsParserService` untouched. No change to capture, categorisation, or the
  spend/income math.
- Migration v25 is one additive nullable column + one new table. Reversible in
  effect (unused columns are harmless).
- New code isolated in new files (`tax_bucket.dart`, `tax_service.dart`,
  `tax_screen.dart`, a `financial_year.dart` helper) + threaded fields on
  `TransactionModel` and additive `DatabaseService` methods.

## Phasing

1. **Phase 1 — core.** Bucket catalog, `tax_bucket` column + model wiring,
   migration v25, manual tagging on transaction detail, the Tax screen (FY
   totals vs caps + evidence-only totals), regime gate, disclaimer,
   localization. Shippable on its own.
2. **Phase 2 — auto-suggest.** `tax_bucket_rules` table, seeded keyword map,
   apply-to-all, suggestion chips on detail.
3. **Phase 3 — export.** Tax Summary PDF/Excel.
4. **Phase 4 — delight (optional).** A Jan–Mar Home card ("₹60,000 of 80C
   headroom before 31 Mar"); optional Plus-gating (fits "monetise depth, not
   utility").

## Testing

- **Unit**: FY window math (esp. the Mar/Apr boundary and leap years);
  `sumByTaxBucket` with mixed/absent buckets; cap-override precedence; the
  regime gate (new-regime → feature suppressed); evidence-only buckets never
  presented as a capped deduction.
- **Migration**: seed a v24 DB, upgrade, assert the column exists, all rows
  intact with null buckets, no crash. (Reuse this session's real-DB upgrade
  method on the emulator.)
- **Widget**: Tax screen renders in all six languages and both theme families
  without overflow; disclaimer always present.
- **Export**: golden-ish check that a tax-summary PDF/Excel groups by bucket
  and carries the disclaimer.
- Full suite green + `flutter analyze` clean before any merge.

## Open questions for the owner

1. **Plus-gated or free?** Fits the "charge for depth" idea; also a natural
   seasonal upsell. Default assumption: free in Phase 1, revisit at Phase 4.
2. **Entry point** — Settings → Data only, or also a seasonal Home card? (I'd
   do Settings first, add the card in Phase 4.)
3. **Bucket set** — start with the six above, or include 80TTA/80TTB (savings
   interest) and 80CCD(2) from day one? (I'd keep Phase 1 to the six most-used.)
