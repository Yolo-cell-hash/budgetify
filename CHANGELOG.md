# Changelog

All notable changes to Budgetify are documented here. Dates are in
`YYYY-MM-DD`. Everything stays on-device — these features add capability
without adding any network access.

## [1.61.0] — 2026-08-05

### Added

- **Set each person's share of a split by hand.** Splitting a bill three ways
  only ever offered one answer: your share, and the rest divided equally —
  but the friend who ordered the wine owes more than the one who had soup.
  Every person's amount is now a field you can type into, and the people you
  haven't touched absorb the difference: on a ₹10,000 bill with ₹2,000 yours,
  putting ₹5,000 on one person leaves ₹3,000 on the other, with no arithmetic
  to do. Changing your own share realigns them the same way, and ↺ hands a
  row you set back to the automatic split. When the parts stop adding up, the
  sheet says by how much and offers a one-tap **Even it out** — then lets you
  save it anyway, because tracking a slice of a bill is a legitimate thing to
  want. The ledger records exactly what you entered.

### Fixed

- **The transaction list keeps your place when you come back to it.**
  Scrolling a long way down, opening a transaction and tagging it landed you
  back at the very top, with all that scrolling to do again. The list wasn't
  forgetting its position — it was being destroyed: every reload swapped the
  whole list out for a loading spinner, and the scroll position went with it.
  Refreshes that only update what's already on screen (coming back from a
  transaction or from Add, a delete, an undo, pull-to-refresh) now leave the
  list in place. Filter and search changes still start at the top, where a
  new result set belongs.
- **Settings shows the version you are actually running.** The About row read
  1.48.0 while the app shipped as 1.60.0 — it was a hand-maintained constant
  that release bumps kept forgetting. It is now checked against the real
  version by the test suite, so the two can't drift apart again.
- **The Clear action on a transaction's Category card sits at the right
  edge.** It had been floating well short of it.

## [1.60.0] — 2026-08-04

### Changed

- **The app no longer jumps to Budgets when you go over.** Being thrown onto
  a screen you didn't ask for reads as a malfunction, not as feedback. The
  reaction is simply *owed*: it waits, and plays the moment you open your
  budgets yourself — this launch or three launches later. The debt is
  remembered across restarts, so it can't quietly expire, and it's settled
  only when the animation actually plays.

### Fixed

- **Split bills now count as your share everywhere.** A ₹645 dinner split
  down to ₹145 was still being counted at the full ₹645 in **Daily
  Analysis** — its spend total, its category breakdown and the amount on each
  row. The same slip was in the **7-day chart on Home**, the **month totals
  above the transaction list**, the **merchant detail** totals (month, average
  and largest), and the **"large spend" coach tip**, which could flag a bill
  you only paid a fifth of. Every spending figure in the app now uses your
  own share, matching the headline on the transaction itself.

## [1.59.0] — 2026-08-04

### Fixed

- **The over-budget attack no longer hides behind a switch.** The full-body
  royal attack was gated behind **Enable Custom Animations** — an opt-in,
  default **off**, buried in the avatar picker. The flagship moment of
  Gamified Budgets was invisible to everyone who never found the toggle,
  which is nearly everyone. The attack is *feedback about your money*, not
  decoration, so it now plays whenever a royal is equipped and Gamified
  Budgets is on. The toggle keeps governing the decorations: the welcome
  parade, the ambient cameos, the cheers.
- **One gated attempt no longer silences the month.** The breach was marked
  "reacted to" the moment the reaction was *requested* — even if it was then
  dropped because the toggle was off or the royal hadn't finished loading.
  One swallowed attempt meant silence for the rest of the month. The record
  is now a picture of *which budgets were over at the last look*, and the
  reaction fires on every **crossing**: reopening on the same blown budget
  stays quiet, but going over → back under → over again fires each time —
  ₹790 of ₹800, close the app, spend ₹20, reopen: Budgets screen, ₹810,
  attack.
- **A scold can't outrun the royal any more.** On a cold start the
  over-budget verdict often arrived before the equipped royal had finished
  loading, and the reaction was silently discarded. It now waits for the
  royal, and — being feedback — jumps ahead of the welcome parade instead of
  queueing behind six seconds of pageantry.

## [1.58.0] — 2026-08-04

### Added

- **Blowing a budget takes you to it.** When you cross a limit, the app now
  opens the Budgets tab on the gauge that broke, instead of announcing it
  wherever you happen to be and leaving you to go find which budget it was.
  This happens on a cold start too: reopen the app after a charge pushed you
  over and you land on the Budgets screen showing the new total. Once per
  breach, so it never hijacks a launch twice for the same thing, and it works
  whether or not the royal animations are switched on.

### Fixed

- **Retagging a transaction now updates your budgets.** Tagging a spend and
  then moving it to **Self Transfer** or **Investments** takes it out of your
  spending — but the Budgets tab kept showing the old figure until the app was
  restarted. The screen was built once and never told the data underneath it
  had changed. It now refreshes whenever anything changes what's been spent:
  a retag, a new charge, a deletion.
- **Cutting a budget below what you've already spent counts as going over.**
  ₹1,000 budget with ₹900 spent, dropped to ₹800 — you are over, without
  spending another rupee, and the reaction now fires.
- **The over-budget animation waits for the gauge properly.** It was raised
  the moment the breach was noticed, which is usually a moment when the ring
  it attacks isn't on screen — mid-launch, or with the budget dialog still
  closing over it. It now waits for the gauge to actually be there (through a
  tab switch, a screen load and a dialog unwinding) and plays on it, falling
  back to playing wherever you are rather than being dropped.

  *Note: these full-body animations are opt-in — **Enable Custom Animations**
  in the avatar picker, with a royal equipped and Gamified Budgets on.*

## [1.57.0] — 2026-08-04

### Added

- **Subscriptions that add themselves.** When you set up autopay for anything
  — Google Play, Spotify, a Groww SIP — your bank registers a **UPI mandate**
  and texts you about it. Budgetify now reads those messages, so a new
  subscription appears on the Recurring screen the day you subscribe, with the
  exact amount and (where the bank states it) the first debit date. Until now
  the app could only *infer* a subscription from three look-alike charges, which
  meant three months of it being invisible. Suggestions only, as before:
  nothing is added to your subscriptions until you tap **Track** and save it,
  and each one can be dismissed on its own. Mandate suggestions carry an
  **AUTOPAY** badge, because "your bank told us" is a different claim from "we
  noticed a pattern". Registrations from ICICI, HDFC, BOI and SBI are read.

### Fixed

- **A mandate being *set up* is no longer logged as money moving.** No money
  changes hands when autopay is registered, but SBI's wording ("Your
  UPI-Mandate for Rs.1950.00 is successfully created towards Google Play from
  A/c No: X") read enough like a credit that it was landing as ₹1,950 of
  **income**. These messages are now recognised for what they are.
- **Autopay charges are counted again.** The reverse mistake: any message
  mentioning "AutoPay" was thrown away as a reminder — including the real
  debits autopay produces. An ICICI mandate charge ("Rs 3000.00 debited from
  ICICI Bank Savings Account XX197 … for UPI Mandate AutoPay Retrieval Ref
  No.X") never reached your spending at all. Genuine autopay debits are now
  logged, while the reminders that don't move money still aren't. Their payee
  reads as the merchant alone ("ICCL Groww Auto") rather than trailing the
  rail description, so repeat charges group together.
- **The over-budget animation now plays when you reopen the app.** The royal's
  attack on the budget gauge only fired if you crossed the limit while the app
  was already open — reopening it on a budget you blew yesterday showed
  nothing, because the app adopted "over budget" as the starting state and
  waited for a change that had already happened. It now reacts once per
  breach: reopening on the same blown budget stays quiet, going over a *new*
  budget, or a new month, gets its own reaction. A scold raised while you're
  elsewhere in the app waits a few seconds for you to reach the Budgets tab so
  it can land on the gauge itself, and plays wherever you are if you don't.
- **The Budgets screen reacts on its own.** Budget state was only ever checked
  from Home, so blowing a limit while sitting on Budgets — by editing the
  limit, or a charge arriving — went unremarked until the next visit to Home.

## [1.56.0] — 2026-08-03

### Added

- **Clearing a tag now reaches as far as tagging did.** Choosing **Apply to
  All** tags every matching transaction *and* writes a standing rule that keeps
  tagging the ones that arrive later. Taking that back was the problem: the
  only visible way out was deleting the tag itself. A transaction that carries
  a tag now shows a plain **Clear** next to the Category heading, and it asks
  how far to reach — **Only this one**, **All from this payee** (with the real
  count), or **All, and stop auto-tagging**, which is the true undo of Apply to
  All. Every one of them is undoable from the toast that follows.
- **An Auto-tag rules screen** (Settings → Data). The rules Apply to All
  creates used to be invisible — written in one tap, then permanent and
  unlistable. Now each one shows what it tags, in which direction, and how
  many transactions currently carry it. Pause a rule to stop it tagging new
  transactions while keeping what it already did, or delete it and choose
  whether the tags it applied go with it.
- **A "tagged automatically" note** on any transaction whose tag came from a
  rule rather than from you, so a tag that appears on its own explains itself
  — and links straight to the rule behind it.
- **Clear from N transactions** in Manage Tags, separate from Delete. Emptying
  a tag and destroying it are different intentions; only one of them was
  available before. Clearing also removes the auto-tag rules that write that
  tag, so it doesn't quietly come back on the next message.

### Improved

- **Canara Bank alerts are read properly.** An interest payout ("…CREDITED to
  your account … towards interest") is filed under **Bank Interest** instead of
  the literal word "interest", so every interest credit across accounts groups
  under one payee. A UPI debit names the person: Canara masks the UPI handle
  away at the "@", which no rule could read, so "pinkygala77@" used to collapse
  to the generic "UPI Transfer" placeholder.
- **ICICI ACH/NACH credits — dividends and interest warrants — name the
  remitter.** These carry the payer only inside a star-delimited narration
  ("Info ACH\*IRB INFRASTRUCTURE D\*164"), which no "from"/"to" rule matches,
  so every one of them arrived with no counterparty at all. Institutional
  remitters ("BANK OF BARODA") are read too, which the general-purpose rule
  deliberately refuses.
- **Money arriving from nobody now asks for a glance.** A UPI credit whose
  payer the bank never names keeps the honest "UPI Transfer" label but lands in
  **Needs review** — an unexplained incoming payment could be income, a refund
  or a friend settling up, and only you can say which. Outgoing payments are
  left alone: you know what you just paid for.
- **A payee can never be your own account.** As a final check on every parse,
  a counterparty that reads as the row's own account number is dropped and the
  transaction is flagged for review — the two sides of a transaction can never
  be the same party, so a row saying "Received from XX2278" directly above
  "Account XX2278" was always a misread. Stored transactions that no rule could
  name are re-read on upgrade, so the history you already have benefits from
  the new Canara and ICICI shapes rather than only new messages.

## [1.53.0] — 2026-07-29

### Added

- **Spending by bank.** Every bank alert arrives under a registered sender
  header — `HDFCBK`, `BOIIND`, `SBIUPI`, `ICICIB`, `AXISBK` — so your spending
  is now totalled per bank as well as per category. Each month lists **only
  the banks you actually used that month**: three accounts with one card in
  use reads as a single row, and the month a dormant account wakes up it
  appears on its own.
- **Banks on Home.** Right under the month's expenses, a strip of small bank
  pills shows each bank and what was spent from it. Tap one for that bank's
  transactions, or **See all** for the full Banks screen, which steps month by
  month.
- **A By bank card in Budgets → Overview**, on every month page, ranked by
  spend with the same drill-down.
- **Bank-wise filtering.** The transaction list gains a one-tap bank strip
  above the results — it shows the banks the *other* filters leave standing,
  with amounts for the period you're looking at, so switching accounts never
  dead-ends. The filter sheet gains a matching **Bank** section.
- **Bank-wise export.** The export sheet gains bank chips, so you can export
  one account's year rather than everything. Every format now carries the
  breakdown: Excel gets a **By Bank** sheet (period total plus a table per
  month), the PDF report a **By Bank** block, and the text report a **BY
  BANK** section per month. The **Bank** column in Excel and CSV now names the
  bank ("HDFC Bank") instead of the raw header ("HDFCBK").
- **1,525 sender headers mapped to 610 banks**, generated from the DLT
  registry in `list_of_banks.txt` by `tool/gen_bank_directory.py`, plus a
  curated supplement for headers the registry omits — including neobanks like
  Jupiter, Fi Money and Niyo, which file under their own header. This is what
  makes one bank one row: State Bank of India alone files under 273 headers.
  Statement imports merge into the bank their label names ("HDFC Savings"
  joins HDFC Bank), and manual entries keep their own bucket.
- **A header we can't name still counts.** An unrecognised sender keeps its
  raw header as its identity, so its spending is totalled, filtered and
  exported like any other bank — a co-operative bank outside the registry is
  never silently dropped from your totals. It is labelled **"<header> ·
  Unknown bank"** rather than passing itself off as a bank named "JUPITR".
- **Call your banks what you call them.** The pencil on any row of the Banks
  screen renames it: "HDFC Bank" can read **HDFC Salary**, and a header we
  couldn't name reads whatever that account is to you. The name is a label
  only — the transactions stay wired to the sender header they arrived under,
  so nothing moves between rows, future messages from that bank still land
  there, and one name covers every header the bank sends from (all 273 of
  SBI's). Clearing the field restores the detected name. Your names appear
  everywhere the bank does, exports included, and ride along in encrypted
  backups.

### Fixed

- **Exports no longer count transfers as spending.** The summary block in the
  Excel, PDF and text exports added self-transfers, investments and
  settlements into **Total Expenses**, so an exported report disagreed with
  every screen in the app — a ₹8,000 move between your own accounts read as
  ₹8,000 spent. Those now sit on their own **Moved (not counted)** line, and
  the text report lists them under a **MOVED, NOT COUNTED** heading so nothing
  vanishes. Split transactions count your share, as they do everywhere else.
- **The PDF footer no longer prints a tofu box.** The em-dash in
  "Budgetify — *motto*" has no glyph in the built-in Helvetica the report
  uses; it is now the middot the tax report already used.

## [1.49.0] — 2026-07-26

### Changed

- **Removing an entry now asks what kind of removal you meant.** Swiping a
  transaction away used to offer only *Delete*, which quietly tombstones that
  one message — so a recurring promo came back the next month with a new amount
  and had to be deleted again. The confirmation now offers **Not a
  transaction** (which also skips every future message matching that template
  from that sender) alongside **Just remove this one**, and each option says
  what it will do. The same choice appears from the detail screen, from bulk
  selection, and in Tidy up, so every route behaves identically.
- **Removals can be undone.** The toast after a removal carries **Undo**, which
  restores the entry — and lifts the mute if one was added. Undo survives an
  app restart: the deleted entry is kept whole until you move on.

### Added

- **Tidy up.** Entries the reader wasn't sure about are gathered into one
  short pass — **Looks right**, **change the direction**, or **Not a
  transaction** — with a plain finish when the queue is empty. A prompt appears
  on Home only when something is waiting, and disappears once it isn't.
- **Select several at once.** Long-press any transaction to start selecting,
  then remove the lot in one go. Long-press is also a non-gesture alternative
  to swiping, for anyone who can't swipe reliably.
- **Screen-reader support on the transaction list.** Each row is announced as a
  single sentence — direction, amount, payee, category, date — and removal is
  exposed as a proper accessibility action rather than being swipe-only.
- **Ignored messages shows how many.** Settings → Ignored messages now carries
  a count, so muting a message shape is visible after the fact and easy to
  reverse.

### Fixed

- **State badges no longer get cut off.** On narrower phones — and in Hindi,
  Marathi, Bengali, Telugu and Tamil — the "Check" badge could be clipped off
  the right edge of a card, which hid the one on-card pointer toward fixing a
  misread entry. Badges now wrap instead of overflowing, and a large amount at
  a big text size shrinks to fit rather than being clipped.
- **Attention badges follow the theme.** "Unclassified" and "Check" were fixed
  light-mode colours that painted unchanged on Dark, Onyx & Amber, Royal Indigo
  and Midnight Indigo. They now use the theme's own palette.
- **Dialogs scroll instead of overflowing** at large text sizes, where a long
  dialog could previously push its own buttons out of reach.

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
