# Payment-App Notification Capture — Design & Decisions

_Implemented in v1.44.0 (branch `claude/notification-capture`) · 2026-07-23_

## Why

Two structural threats to the SMS-only model, one mechanism answering both:

1. **Banks are switching off small-value UPI SMS** (HDFC: nothing under ₹100
   spend / ₹500 credit, purely SMS-cost economics). Sub-₹100 UPI is the bulk
   of Indian transaction *count*; an SMS-only tracker goes blind exactly where
   "where did my money go?" lives.
2. **Play's restricted `READ_SMS` policy** can revoke the entire ingestion
   pipeline with a policy update. Notification access is a separate, unrestricted
   (though still sensitive) permission — a second, independent leg to stand on.

The payment app's own notification ("₹40 paid to Chai Point") still records
every payment. FinArt, Mera Kharcha and Trakio all read it; now Budgetify can
too — without touching the no-`INTERNET` architecture.

## Architecture

```
payment app posts notification
        │
        ▼
TxnNotificationListener (Kotlin, always-on once access granted)
  1. package allowlist  ←──────── THE privacy gate, first statement
  2. enabled flag (Flutter prefs, read natively)
  3. skip group summaries / ongoing
  4. content-hash LRU (re-posted copies)
  5. append JSON line → filesDir/notif_capture_queue.jsonl
  6. nudge live engine (MethodChannel), if any
        │
        ▼  (file read — no channel needed, works in any isolate)
NotificationCaptureService.drain()        triggers: launch · resume ·
  consumed-watermark skip                 live nudge · hourly WorkManager scan
        │
        ▼
NotificationParserService.parse()   strict completed-payment grammar
        │
        ▼  mute check → payee alias → keyword classify → type override
        ▼  → fingerprint → exists? → reconciler → rules → insert
        ▼
aftermath mirror of the SMS paths: fresh-only alert, budget thresholds,
widget refresh, app-data-changed signal
```

### The twin problem (the hard part)

One real payment can arrive twice: app notification (~1 s) and bank SMS
(seconds–minutes later, sometimes never for sub-₹100). Their fingerprints
differ (different sender, different text), so the unique index cannot help.

`TransactionReconciler` matches **same type + same amount within ±30 min**,
with a **payee guard** (two known, unrelated names veto the merge — two ₹50
autos to different people stay two transactions). Resolution is asymmetric:

| Arrival order | Action |
|---|---|
| notification, then SMS | SMS **absorbs** the row in place: keeps id, payment-time, category/tags/splits/notes (user edits), takes SMS sender/message/account/**fingerprint** (so the next inbox rescan recognises it) |
| SMS (or manual entry), then notification | notification is **dropped** — SMS is richer; the user's own manual entry always wins |
| user deleted one copy, other arrives | dropped via **enriched tombstones** (v25 adds amount/type/sender to `deleted_transactions`) — deleted stays deleted across channels |

Chosen over the earlier quarantine idea (hold notification ~90 s waiting for
SMS): a quarantine loses payments when the process dies, and SMS can outwait
any window — so the SMS-side absorb check is needed regardless, which makes
the quarantine pure added risk. Commit-immediately + reconcile-on-arrival has
no timer, no held state, and real-time UX.

### Why a file queue, not a background Dart isolate

The listener must work with no Flutter engine alive. Spinning an engine per
event (telephony-plugin style) is the most crash-prone pattern in Flutter
Android; instead Kotlin appends to a JSONL file and Dart drains it on its
own schedule. The WorkManager isolate has no access to MainActivity's method
channel — irrelevant here, because draining is a plain `dart:io` file read.
Crash-safety comes from idempotency, not protocol: replayed events re-parse
to the same fingerprint and hit `ConflictAlgorithm.ignore` / the exists
check. The consumed-watermark is an optimisation only. Kotlin trims the file
(rename-over, atomic) at 800→500 lines.

### Privacy invariants

- Allowlist check is the **first statement** in `onNotificationPosted`;
  non-payment-app notifications are never stored, parsed, logged, or sent
  across the platform channel. Dart re-checks the package (skew guard).
- **WhatsApp is excluded deliberately** — messaging app; reading its
  notifications = reading personal messages, WhatsApp Pay notwithstanding.
- Bank apps excluded — their payments already arrive as richer bank SMS.
- Off by default. Two independent gates: in-app toggle AND system access.
  Toggle off ⇒ the listener stores nothing even if access remains granted.
- The enable dialog names every watched app before the system hand-off.
- No `INTERNET` permission, unchanged. Queue file is app-private and transient.

### Grammar: precision over recall

A missed sub-₹100 chai is the status quo; a false positive corrupts totals.
Rejected outright: requests/collect, failed/pending/scheduled, reminders/due,
refunds (the eventual bank credit is the truth), cashback/rewards/offers/
scratch cards, wallet top-ups (bank SMS records the debit side), mandate
setups, OTPs. Accepted: completed-action verbs only, EN + basic HI. Payee-less
parses land in the existing review queue (`ReviewReasons.payeeUnknown`).

## No-regression guarantees

- Feature off (default): the Kotlin service returns at the enabled-flag
  check; the SMS paths' only addition — `absorbIntoNotifTwin` — short-circuits
  on a memoised prefs flag before any query. Hot path byte-identical.
- `SmsParserService` untouched. New logic lives in new files:
  `notification_parser_service.dart`, `notification_capture_service.dart`,
  `transaction_reconciler.dart`, `TxnNotificationListener.kt`.
- Migration v25 is additive nullable columns on `deleted_transactions` only.
- Verified: `flutter analyze` clean (no new warnings), full test suite green
  (598 + 41 new), debug APK compiles.

## Known limits / deferred

- **Regional-language notification copy** (a Hindi-locale GPay posts "₹50 का
  भुगतान…"): basic Hindi verbs parse; MR/BN/TE/TA copy is silently skipped
  (fails safe — never mis-parses). Extend `_debitRegex`/`_creditRegex` per
  language with tests.
- **No history**: notification access starts at grant time; SMS backfill
  remains the only historical source. Inherent to the API.
- **Android 14+ binds listeners only after first unlock**; a payment in the
  boot-to-unlock window is missed (usually recovered via its SMS).
- **OEM listener kills (Xiaomi/vivo)**: `requestRebind` nudging not yet
  implemented; the hourly drain caps the damage. Revisit if field reports show
  gaps.
- **Simultaneous-insert race** (SMS listener isolate vs a drain, same second):
  both sides could pass their checks and insert twice. Window is milliseconds;
  the duplicate is visible and deletable; accepted for v1.
- **Play Console**: the listing's Data-Safety + a prominent-disclosure line for
  notification access must be updated before this ships to production.
- Allowlist expansion (Navi, Slice, bank apps?) is a one-line-per-app change
  in `TxnNotificationListener.kt` + `notification_parser_service.dart` (keep
  in sync) — deliberately conservative at launch.
