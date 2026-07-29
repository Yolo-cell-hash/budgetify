# Payment-App Notification Capture — Design & Decisions

_Implemented in v1.53.0 (branch `claude/notification-capture`) · 2026-07-23,
PayZapp + declared coverage 2026-07-29_

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

## What each app can actually see (added 2026-07-29)

The allowlist is not uniform, and pretending otherwise is the feature's
sharpest failure mode. Two bands, declared per app in
`NotificationParserService.watchedPackages` as a `NotifCoverage`:

| Band | Apps | What arrives |
|---|---|---|
| `bothWays` | **PayZapp** | Debits *and* credits. "Payment sent successfully — Your payment of Rs.200 to Ashokkumar Sharma was successful." and "Received Money — You received Rs.1 from JAY RAJESH KEER". Self-sufficient: with no bank SMS at all, the ledger still closes. |
| `creditsOnly` | GPay, PhonePe, Paytm, BHIM, CRED, Amazon Pay, MobiKwik, Freecharge | Credits only. These apps end a payment on an in-app success screen and post **no notification** for it — there is nothing for any parser to read. Spends through them still depend on bank SMS. |

This is a property of the apps, not a gap in the grammar: a UPI app has no
reason to notify you about a payment you are already looking at the
confirmation for. `_debitRegex` would happily parse a PhonePe debit alert if
one were ever posted, and the band is metadata only — nothing in the capture
path branches on it.

**Why it is surfaced in the UI.** "Capture from payment apps" reads like a
complete second pipeline. Someone who enables it for the sub-₹100 spends the
banks stopped SMSing, and then sees only credits appear, will reasonably
conclude the reader is broken and turn it off. So Settings shows the two
bands — in the enable dialog *and* behind a permanent **Which apps are read**
row, because the question ("why only credits?") is asked weeks after the
one-time dialog is dismissed. The row doubles as the standing privacy
disclosure of the allowlist.

**PayZapp is not a bank app.** `com.enstage.wibmo.hdfc` is HDFC's UPI/wallet
app (Wibmo-built, hence the package name), not the HDFC Bank app
(`com.snapwork.hdfc`), which stays off the list under the existing rule that
bank apps are already covered by richer bank SMS. Its payee copy is also the
only one that puts the verdict *after* the name ("… to Ashokkumar Sharma was
successful."), which is why `was`/`were` are connectives in the payee
lookahead — without them the payee parses as "Ashokkumar Sharma Was".

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

**Placeholder payees are "unknown", not a conflict.** A real ₹40 payment
reaches the app as *"Chai Point"* from the alert but as the uniform
placeholder *"UPI Transfer"* from the bank SMS (pattern 10 in the SMS
parser). Treating that placeholder as a competing name makes the payee guard
veto a perfect match and double-count the payment — found on-device, fixed in
`payeesCompatible` via the same convention `isAccountFallbackPayee` uses
(`UPI Transfer` + masked-account shapes). `ATM` and `Bank Charges` stay
*identifying* and still veto. The merge then uses `preferredPayee` so
absorbing the SMS never downgrades a real merchant name to the placeholder.

**Tombstone suppression is asymmetric on purpose.** The SMS side only defers
to tombstones of deleted **`NOTIF-`** rows. A deleted *SMS* must never
suppress a later, genuinely different SMS of the same amount — that would be
silent data loss, strictly worse than a visible duplicate the user can delete
again. The whole check sits behind `captureEverEnabled()`, so it cannot fire
for a user who never turned capture on.

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
- Migration v28 is additive nullable columns on `deleted_transactions` only
  (amount/type/sender, alongside main's `payload`). Manual rows leave all
  four null, exactly as they leave the fingerprint/message keys null.
- Verified: `flutter analyze` clean (no new warnings), full test suite green,
  debug APK compiles.
- **Device-verified on a Pixel-class emulator (API 37)**: opt-in flow, the
  privacy gate (a non-allowlisted app posting perfect payment copy produced no
  queue file at all), capture with the app force-stopped, drain on launch and
  on resume, both twin orders, repeated-rescan idempotency, cross-channel
  tombstones, and an SMS-only clean install left completely unaffected.

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
- **Debits from the eight `creditsOnly` apps are unreachable**, not merely
  unimplemented — the alert is never posted. Now stated in-app rather than
  left for the user to discover (see *What each app can actually see*). The
  only ways to widen this are more `bothWays` apps and bank SMS.
- Allowlist expansion (Navi, Slice, bank apps?) is a one-line-per-app change
  in `TxnNotificationListener.kt` + `notification_parser_service.dart` (keep
  in sync — and set the new entry's `NotifCoverage` from observed alerts, not
  from what the app *could* post) — deliberately conservative at launch.
