# Restore Purchases — Implementation Plan

**Problem.** Budgetify has no accounts, no login, no server, and no INTERNET
permission in the release build. If a paying user deletes the app and
reinstalls it (or moves to a new phone), how do they keep what they paid for?

**Answer in one line.** The Google account *is* the account: Google Play keys
every purchase to the user's Play (Google) account, not to the install — so
`queryPurchases()` on the fresh install returns everything they own, with no
app-side identity at all. Everything below is engineering around that fact.

---

## 1. What we sell (catalog: `lib/models/plus_products.dart`)

| Product id | Type | Price | Grants |
|---|---|---|---|
| `plus_lifetime` | one-time non-consumable | ₹699 | Plus forever |
| `plus_yearly` | auto-renewing sub | ₹299/yr | Plus while active |
| `plus_monthly` | auto-renewing sub | ₹29/mo | Plus while active |
| `royal_<id>` ×6 | one-time non-consumable | ₹49 | that royal avatar |

Royal products: `royal_sovereign`, `royal_empress`, `royal_prince`,
`royal_darkprince`, `royal_princess`, `royal_royalmedic`. Any 2 royals remain
free via streak picks (10- and 24-day streaks) — purchases and picks are
tracked separately so a purchase never consumes a pick.

Product ids are immutable once live. The Play Console products MUST be created
with these exact ids.

## 2. Layered design (already in the codebase, dormant)

```
Play Billing (later)          ──►  BillingGateway            (interface)
UnavailableBillingGateway     ──►  ships today: store closed
        │
        ▼
BillingService                ──►  purchase() / restorePurchases()
        │                          grants are idempotent, add-only
        ▼
EntitlementService            ──►  local CACHE of ownership + trial clock
        │                          hasPlus / hasFullAccess / allows(feature)
        ▼
Feature gates                 ──►  notification choke points, category-budget
                                   creation, tag bulk-apply, royal equip rule
```

* **EntitlementService** persists: `entitlement_plus_lifetime` (bool),
  `entitlement_plus_until` (ms epoch, subscription window incl. 3-day grace),
  `entitlement_owned_royals` (string list). All keyed in SharedPreferences
  next to the trial anchor.
* **Everything fails open.** Unknown/unreadable state ⇒ feature allowed. A
  paying user must never be locked out by a bug; a freeloader getting a few
  extra days is an acceptable cost.
* **Data is never deleted on lock.** Category budgets etc. go quiet, not away.

## 3. The three restore layers (defense in depth)

### Layer 1 — Play `queryPurchases()` (the real mechanism)
On reinstall, first launch calls `BillingService().restorePurchases()`:
non-consumed one-time products (lifetime, royals) and active subscriptions
come back from the Play Store app over **local IPC — no INTERNET permission
needed in our app**; the Play Store app does the networking. Each returned
purchase re-runs the same grant path as a fresh purchase (idempotent).

Trigger points for a silent restore pass:
1. First launch after (re)install — once, deferred, after first frame.
2. When a gate is about to deny — one last `queryPurchases` before showing
   the paywall (catches "new phone, hasn't restored yet").
3. The explicit **Restore purchases** button on the Plus screen (already
   built) — the user-visible safety net, standard Play policy expectation.

### Layer 2 — OS Auto Backup (free, already on)
`allowBackup` is platform-default true; SharedPreferences (trial anchor +
entitlement cache) ride Google's device-to-device / cloud restore. A restored
device often arrives *already entitled* before Play is even queried.

### Layer 3 — Budgetify's own encrypted backup
`EntitlementService.exportSettings()` now includes the paid cache
(`plus_lifetime`, `plus_until`, `owned_royals`) alongside the trial anchor.
Import rules are asymmetric on purpose:
* **Trial anchor: earliest-first-launch wins** — a backup can never extend a
  trial.
* **Paid cache: add-only union / max** — a backup can only ever ADD ownership,
  mirroring what a Play restore could prove anyway.

Yes, a crafted backup could claim `plus_lifetime`. Accepted: the app is fully
client-side (no server to verify against), the backup is encrypted, and the
alternative (denying restores) hurts real customers. Play remains the truth
wherever it is reachable; a later phase can re-verify cached grants against
`queryPurchases` and quietly drop ones Play disowns (with a long grace window
and only when Play answers authoritatively).

## 4. Subscription expiry without a server

No server ⇒ no Real-Time Developer Notifications. Instead:
* On grant/renewal/restore, extend `entitlement_plus_until` from the later of
  (now, current expiry) by the plan period + **3-day grace**
  (`kPlusSubscriptionGrace`).
* Every foreground session where Play is reachable, refresh via
  `queryPurchases()` — an active sub re-extends the window, an expired one
  simply stops extending, and access ends when the cached window + grace runs
  out. Clock rollback is neutralized by the existing monotonic `_effectiveNow`.
* **Lead with lifetime** (₹699): non-consumables never expire, never need
  re-verification — the perfect offline SKU. The paywall already pre-selects
  it.

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Reinstall, same Google account | Layer 1 restores everything; Layers 2–3 usually got there first. |
| New phone, same account | Same as above (queryPurchases is account-scoped). |
| Different Google account | Purchases genuinely aren't theirs → paywall. This is correct and matches every Play app. |
| Refunded/revoked purchase | Disappears from queryPurchases; cached grant survives until the (later-phase) re-verify pass expires it. Acceptable client-side risk. |
| Pending UPI payment | `BillingOutcome.pending`: grant nothing; the next queryPurchases pass grants it once it settles. |
| Play Store app missing/ancient | Gateway reports unavailable → gates stay… whatever the cache says; fail-open covers the rest. |
| Clock wound back to fake trial/sub | Monotonic `entitlement_last_seen_at` guard already blocks it. |

## 6. Billing-day checklist (when bank + Play approval land)

1. Add `in_app_purchase` (or `billing_client`) dependency.
2. Implement `PlayBillingGateway implements BillingGateway` (~150 lines):
   `isAvailable` → connection check; `queryPurchases` → map `PurchaseDetails`;
   `launchPurchase` → buy flow + **acknowledge within 3 days** (unacknowledged
   purchases auto-refund).
3. Swap the gateway in `BillingService` (one line) + add the silent restore
   triggers (§3).
4. Create the 9 products in the Play Console with the §1 ids; real prices come
   from `ProductDetails` at display time (the catalog's ₹ constants are only
   the pre-billing preview).
5. **CRITICAL VERIFICATION:** internal-track build, INTERNET still stripped —
   complete a sandbox purchase AND a reinstall-restore round-trip. This
   validates the local-IPC assumption everything rests on.
6. Grandfather closed testers with Play promo codes for `plus_lifetime`.
7. Royal purchases: replace the picker's "Coming soon" pill with the ₹49 buy
   flow (backend — ownership, equip-honouring, backup — is already live).

## 7. What was deliberately NOT done now

* No billing dependency added (nothing to configure, nothing to break).
* No UI change to the royal picker — locked royals still say "Coming soon".
* No paywall entry point in any menu — only the dormant gates can open it,
  and every gate passes while the (silent) 6-month trial runs.
