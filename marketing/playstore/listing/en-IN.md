# Play Store listing — English `en-IN` (use for `en-US` too)

> Paste each block into **Play Console → Grow → Store presence → Main store listing**.
> Limits: title 30 · short description 80 · full description 4000.
> Run `python3 marketing/playstore/listing/validate.py` before pasting.

---

## App name  `26/30`

```
Budgetify: Expense Tracker
```

**Why this and not just "Budgetify":** the title is the heaviest text-relevance
signal in Play search. `Budgetify` alone contains no category keyword, so the
listing is not competing for a single category query. `Budgetify` stays the
leading token, so the #1 rank for the brand query is preserved, and
`Expense Tracker` adds an exact-phrase match on the highest-volume head term in
the category. It reads as a natural product name, which keeps it clear of the
keyword-stuffing rule in Play's metadata policy.

**"Budget" is covered by the short description** — `budget tracker` matches
across title + short description, so the 30 characters go to the phrase that
cannot be recovered elsewhere.

---

## Short description  `74/80`

```
Budget tracker & money manager. Auto-logs bank & UPI SMS. Offline, no ads.
```

Carries the head phrases the title cannot fit — `budget tracker`,
`money manager`, `UPI`, `offline` — plus the two differentiators that make
someone tap (`auto-logs bank & UPI SMS`, `no ads`).

`UPI` earns its place over a bare "100%": it is a high-intent India-specific
query token (`upi expense tracker` is a live query with its own result set),
whereas "100%" adds emphasis but no searchable term. The full description still
makes the 100%-offline claim in full.

---

## Full description  `3,027/4000`

```
Budgetify is the private expense tracker and budget planner that logs your spending for you — automatically, and entirely on your phone. No sign-up. No cloud. No ads. No internet permission. Your money data never leaves your device.

Most money manager apps make you type in every transaction by hand, or ask you to hand your bank logins to a server. Budgetify does neither. It reads the bank and UPI transaction SMS you already receive, turns them into clean, categorised entries, and shows you exactly where your money goes.

✨ WHY BUDGETIFY
• A 100% offline expense tracker — the app doesn't even request internet access, so your data physically can't be uploaded
• No accounts, no ads, no analytics, no trackers — ever
• Automatic expense tracking from bank & UPI SMS — little to no manual entry
• Made for India: understands rupees, UPI, EMIs and bank alerts out of the box

📩 AUTOMATIC SMS EXPENSE TRACKING
Budgetify spots transaction messages from banks and payment apps and pulls out the amount, date, merchant and account — instantly logging your income and expenses. Known merchants are auto-categorised. Prefer to go fully manual? Deny the SMS permission and add entries yourself, like any daily expense manager.

📊 A COMPLETE MONEY MANAGER
• Budget tracker — set monthly and per-category budget limits and watch your progress
• Spending analytics — category donut, daily spend curve, merchant breakdowns and spending by bank
• Categories & tags — organise spending your way, with custom tags
• Savings goals — set targets and log every contribution
• Net worth — record assets, liabilities, SIPs and holdings over time
• Recurring payments — stay on top of subscriptions, rent and EMIs with reminders
• Splits & ledger — record shared expenses and who owes whom, with no accounts for anyone
• Tax deductions — tag spends into 80C, 80D, 24(b) and HRA as you go
• Statement import — bring in CSV or Excel bank statements for the months your SMS never saw
• Home-screen widget — this month's spending at a glance

🔒 PRIVATE BY ARCHITECTURE
• No internet permission — a hard, verifiable guarantee, not just a promise
• App lock with fingerprint or face unlock
• Privacy Mode hides every amount with a single tap
• AES-256 encrypted backups, protected by a passphrase only you know

📈 STAY MOTIVATED
Build streaks, unlock achievements and titles, and celebrate your month with a shareable Monthly Wrapped. A financial health score and a quiet money coach tell you when a category is running hot — without nagging.

📤 YOUR DATA, YOUR CONTROL
Export to Excel, CSV, PDF or plain text anytime. Delete anything in a tap. Because nothing is stored on a server, there is never anything to request back or wait on.

🌍 SPEAKS YOUR LANGUAGE
Available in English, हिन्दी, मराठी, বাংলা, తెలుగు and தமிழ்.

Whether you want a simple daily expense tracker, a monthly budget planner, or a full offline money manager, Budgetify keeps it automatic, accurate and completely private.

Download Budgetify and see where your money really goes.
```

---

## What changed from the live description, and why

| Change | Reason |
|---|---|
| Opens with **"expense tracker and budget planner"** | The first line is weighted highest in the description. The live copy opened with "expense tracker and money manager" and never used *budget planner* or *budget tracker* at all. |
| Section heading **"A COMPLETE MONEY MANAGER"**, bullet **"Budget tracker — …"** | Puts the exact phrases `money manager` and `budget tracker` in structurally prominent positions. |
| Added **daily expense manager, spending analytics, budget limits, daily expense tracker, monthly budget planner** | Covers `expense manager`, `spending tracker`, `budget planner` — head terms the live copy missed entirely. |
| Added tax deductions, statement import, home-screen widget, financial health score, money coach, spending by bank | The live description is stale: it describes roughly v1.30 and omits about a year of shipped features. |
| Languages corrected to **six** | Live copy claims four; the app ships English, Hindi, Marathi, Bengali, Telugu and Tamil. |
| Removed the **"import your existing axio tags"** sentence | Naming a competitor app in your listing is the kind of reference Play's metadata policy treats as an irrelevant cross-reference. The feature still exists — keep it in the changelog and in-app copy, just not in indexed store metadata. Re-add it if you judge the interop callout worth the risk. |

## Before publishing, confirm

- [ ] **In-app purchases** — Budgetify Plus is live in the app, but the store page shows no "In-app purchases" badge. Check the Play Console monetisation declaration matches reality.
- [ ] Feature parity — every claim above is verified against `README.md` at v1.69.0. Re-check if you publish after a feature is removed.
