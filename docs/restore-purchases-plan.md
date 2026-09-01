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
| `plus_lifetime` | one-time non-consumable | ₹1,499 | Plus forever |
| `plus_yearly` | auto-renewing sub | ₹499/yr | Plus while active |
| `plus_monthly` | auto-renewing sub | ₹49/mo | Plus while active |
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

**Don't over-trust this layer.** Auto Backup restores during device setup and
D2D migration — a plain uninstall→reinstall on the *same* device generally does
not trigger it. Treat it as a bonus on new devices, never as the mechanism.

### Layer 3 — Budgetify's own encrypted backup
`EntitlementService.exportSettings()` now includes the paid cache
(`plus_lifetime`, `plus_until`, `owned_royals`) alongside the trial anchor.
Import rules are asymmetric on purpose:
* **Trial anchor: earliest-first-launch wins** — a backup can never extend a
  trial.
* **Paid cache: add-only union / max** — a backup can only ever ADD ownership,
  mirroring what a Play restore could prove anyway.

The trial anchor takes **two** independent witnesses from a backup, both
floors, earliest wins:
1. `entitlement.first_launch_at` — the anchor the backup carries.
2. The envelope's own `createdAt` — when the file was *written*. This one sits
   outside the entitlement block, so deleting that block from a decrypted
   backup no longer buys a clean trial: a file written five months in still
   dates the install five months back.

Yes, a crafted backup could claim `plus_lifetime`. Accepted: the app is fully
client-side (no server to verify against), the backup is encrypted, and the
alternative (denying restores) hurts real customers. Play remains the truth
wherever it is reachable; a later phase can re-verify cached grants against
`queryPurchases` and quietly drop ones Play disowns (with a long grace window
and only when Play answers authoritatively).

## 4. Subscription expiry without a server

No server ⇒ no Real-Time Developer Notifications. Instead, `entitlement_plus_until`
takes the furthest of **two independent witnesses**, and only ever moves forward:
* **Purchase-anchored.** `purchaseTime + period + 3-day grace`
  (`kPlusSubscriptionGrace`), measured absolutely from the receipt. Absolute so
  a replay is idempotent: buying and then tapping Restore recomputes the same
  instant instead of quietly handing out a second month.
* **Live sighting.** `now + 7 days` (`kPlusLiveSightingWindow`), set only when
  Play answered `queryPurchases` with the product *this moment*
  (`confirmedActiveNow`). This is the witness that survives a renewal, and it
  is not optional: **Play keeps the same purchase token across renewals**, so
  the anchored value recomputes to the same stale instant forever and the
  only-ever-extend guard discards it. Without a live sighting a monthly
  subscriber goes dark on day 34 while still being charged.
* A backup import and a re-read receipt are NOT sightings — neither proves
  anything about the present, so neither can resurrect a lapsed window.
* `BillingService.refreshEntitlements()` supplies the sightings: forced at app
  start, and throttled to `refreshInterval` (6h) on resume. Play does not push
  renewals to the purchase stream; querying is the only way to see them.
* Cancel ⇒ Play keeps reporting the sub until the paid period ends, so the last
  sighting lands there and access stops at most 7 days later. That overhang is
  the deliberate cost of never stranding a payer. Clock rollback is neutralized
  by the existing monotonic `_effectiveNow`.
* **Lead with lifetime** (₹1,499): non-consumables never expire, never need
  re-verification — the perfect offline SKU. The paywall already pre-selects
  it.

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Reinstall, same Google account | Layer 1 restores everything; Layers 2–3 usually got there first. |
| New phone, same account | Same as above (queryPurchases is account-scoped). |
| Different Google account | Purchases genuinely aren't theirs → paywall. This is correct and matches every Play app. |
| Refunded/revoked subscription | Disappears from queryPurchases, so the sightings stop and access ends within `kPlusLiveSightingWindow` (7 days). A refunded `plus_lifetime` still sticks — the bool has no expiry — which stays the accepted client-side risk. |
| Pending UPI payment | `BillingOutcome.pending`: grant nothing. If it settles while the app lives, the out-of-band stream grants it; if it settles after the app is closed, the forced `refreshEntitlements()` at next start does. Either way the user never has to find "Restore purchases". |
| Play Store app missing/ancient | Gateway reports unavailable → gates stay… whatever the cache says; fail-open covers the rest. |
| Clock wound back to fake trial/sub | Monotonic `entitlement_last_seen_at` guard already blocks it. |
| "Clear data" to reset the trial | Blocked. `EntitlementService.applyInstallRecordFloor()` re-ages the anchor from Android's package install record, which is not app data and survives the wipe. |
| Reinstall, then restore a backup | Trial continues correctly — the anchor rides in the backup, earliest-wins, and the file's own `createdAt` backs it up. |
| Reinstall and start FRESH (no restore) | **Genuinely resets the free window — accepted.** No server, no accounts, no INTERNET: nothing client-side can outlive an uninstall. The price is their entire history — transactions, tags, rules, budgets, streak, earned royals — paid twice a year, forever. That is a steeper toll than ₹1,499 for anyone the app is actually for. Do not ship a "start fresh but keep my data" path; that would be the exploit's front door. |

## 6. Billing-day checklist (when bank + Play approval land)

1. ~~Add `in_app_purchase` dependency.~~ **DONE (1.77.0)** — `^3.3.0`, which
   pulls Play Billing Library 8.0.0.
2. ~~Implement `PlayBillingGateway`.~~ **DONE (1.77.0)** — `isAvailable`,
   `queryPurchases`, `launchPurchase`, `queryPrices`; acknowledges every
   delivered purchase FIRST, before anything that can throw (unacknowledged
   purchases auto-refund after three days).
3. ~~Swap the gateway + add the silent restore triggers.~~ **DONE (1.77.0)** —
   `refreshEntitlements()` at app start (forced) and on resume (6h throttle).
   The third trigger from §3 — one last query before a gate denies — was
   deliberately dropped: resume already covers it, and putting a store round
   trip in front of the paywall would stall the UI for the one user in a
   thousand it could help.
4. Create the products in the Play Console with the §1 ids. **Only the three
   Plus ids are needed today** — royals are still "Coming soon" and nothing
   calls `royalProductId()` yet.
   * `plus_lifetime` as a one-time product; `plus_monthly` and `plus_yearly` as
     **two separate subscription products**, one base plan each. They must not
     be consolidated into one product with two base plans: `_grant` routes on
     product id via `PlusPlan.byProductId`, so a shared id is charged and then
     ignored.
   * **No Console offers, on any of them.** A subscription yields one
     `ProductDetails` per base plan *or offer*, each with its own offerToken,
     and `launchPurchase` takes `.first` — with more than one entry the charged
     price is a coin toss. `PlayBillingGateway` logs loudly if this ever
     happens. The plugin also only reads the singular
     `oneTimePurchaseOfferDetails`, so an offer on `plus_lifetime` would never
     be applied at all. Until the gateway learns to select by offer tag, run
     `plus_offers.dart` windows as real **price edits** in the Console.
   * Prices are read live via `queryPrices` and rendered by the paywall; the
     catalog's ₹ constants are only the fallback before the store answers.
5. **CRITICAL VERIFICATION:** internal-track build, INTERNET still stripped —
   complete a sandbox purchase AND a reinstall-restore round-trip. This
   validates the local-IPC assumption everything rests on. Verified so far only
   on the artifact: the merged release manifest adds exactly one permission,
   `com.android.vending.BILLING` (from the billing AAR, not the Flutter
   plugin), and INTERNET stays absent. **The device half is still outstanding.**
   Use an accelerated test renewal (license testers) to prove the sighting rule
   in §4 — that is the one behaviour no unit test can settle.
6. Grandfather closed testers with Play promo codes for `plus_lifetime`.
7. Royal purchases: replace the picker's "Coming soon" pill with the ₹49 buy
   flow (backend — ownership, equip-honouring, backup — is already live), and
   create the six `royal_*` products at that point.

## 7. What was deliberately NOT done now

* No billing dependency added (nothing to configure, nothing to break).
* No UI change to the royal picker — locked royals still say "Coming soon".
* No paywall entry point in any menu — only the dormant gates can open it,
  and every gate passes while the (silent) 6-month trial runs.
