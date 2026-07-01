# Budgetify — Privacy Policy

**Effective date:** 1 July 2026
**Applies to:** the Budgetify Android application ("Budgetify", "the app", "we", "us")

---

## The short version

Budgetify is a personal budgeting app that runs **entirely on your phone**. It has **no servers, no accounts, no advertising, and no analytics** — and it does not even request permission to access the internet. Everything Budgetify learns about your money stays on your device, under your control.

We don't ask you to trust a promise. We designed the app so that betraying your privacy is **technically impossible**: with no internet access, the app has no way to send your financial data anywhere.

> **In one line:** your money data never leaves your phone unless *you* choose to export or share it.

---

## 1. Privacy by architecture, not by policy

Most apps ask you to trust a written promise not to misuse your data. Budgetify goes further. The app is built **without the Android `INTERNET` permission**. That is a hard, verifiable property of the software, not a marketing claim:

- The app cannot upload your transactions, messages, balances, or any other information — it has no network access to do so.
- There is no backend service that receives your data, because there is no backend at all.
- No login, no cloud sync, no user profile on our side. We never see your data, ever.

This is the foundation of everything below.

## 2. Information Budgetify works with

All of the following is created and stored **only on your device**, in Budgetify's private storage. We, the developer, never receive any of it.

| What | Why the app uses it |
|---|---|
| **Bank transaction SMS** | To automatically detect your income and expenses (see Section 4). |
| **Transactions you add manually** | To track spending the app didn't detect automatically. |
| **Tags / categories** | To organise spending (e.g. Food & Dining, Travel), including tags you create. |
| **Budgets** | Monthly and per-category limits you set, and progress toward them. |
| **Savings goals & contributions** | To track progress toward personal goals. |
| **Net-worth entries** | Assets and liabilities you enter, and periodic snapshots, for net-worth tracking. |
| **Splits & personal ledger** | To record shared expenses and who owes whom. |
| **Recurring payments** | Subscriptions, rent, EMIs and similar, plus reminders. |
| **Streaks, achievements & titles** | To power the app's gamified, motivational features. |
| **App preferences** | Theme, language, scan frequency, app-lock and privacy settings. |

Budgetify does **not** collect your name, email, phone number, contacts, location, device advertising ID, or any other identifier for tracking. It has no reason to, and no way to send them anywhere.

## 3. What we collect about you: nothing

To be completely clear: **the developer of Budgetify collects no personal data whatsoever.** There is no server that could receive it. We cannot see your transactions, your balances, your habits, or even whether you use the app.

## 4. How Budgetify handles your SMS messages

Because bank alerts arrive by SMS, Budgetify can request the `READ_SMS` and `RECEIVE_SMS` permissions to detect transactions automatically. We treat this access with the seriousness it deserves:

- **Purpose limitation.** SMS access is used for **one purpose only**: to identify bank/financial transaction messages and extract the amount, date, merchant/payee, and account so they can become entries in your ledger.
- **On-device processing.** Every message is read and parsed **on your phone**. The parsing logic runs locally; no message is ever sent off the device for analysis.
- **Selective storage.** Budgetify focuses on transactional messages from banks and payment services. The relevant message text is stored **only** in the app's private, on-device database so it can power features like re-tagging and duplicate detection.
- **No transmission, ever.** Message content is never uploaded, shared, or transmitted by the app. With no internet permission, it physically cannot be.
- **Your choice.** Automatic SMS tracking is a convenience you can decline. You may deny the SMS permission (or revoke it in Android Settings) and continue using Budgetify by entering transactions manually.

## 5. The permissions we request, and exactly why

| Permission | Why Budgetify uses it |
|---|---|
| `RECEIVE_SMS`, `READ_SMS` | Detect bank transaction messages automatically (Section 4). Optional — you can use the app without it. |
| `POST_NOTIFICATIONS` | Show on-device alerts: new-transaction prompts, budget threshold warnings, and bill/reminder notices. |
| `USE_BIOMETRIC` | Let you lock the app behind your device's fingerprint/face unlock, if you enable it. |

When you export data or create a backup, the file is saved through Android's own system file picker, so Budgetify needs no permission to write to your device storage. (On Android 12 and older, that picker component carries a legacy read permission used only to let you choose a file — the app never browses, scans, or reads your other files.)

Budgetify does **not** request the `INTERNET` permission, "all files" access, location, camera, microphone, contacts, or advertising identifiers.

## 6. How your data is stored and protected

- **Local, private storage.** Your data lives in a database inside Budgetify's private app storage on your device.
- **Encrypted backups.** When you create a backup, it is encrypted with **AES-256** using a passphrase that only you know. We never see the passphrase, and it is not stored or recoverable — if you lose it, the backup cannot be opened, by us or anyone else. You decide where the backup file is saved.
- **App lock.** You can optionally protect the app with your device's biometric lock.
- **Privacy Mode.** You can hide all amounts in the interface with a single toggle, so nothing sensitive is visible to someone glancing at your screen.

## 7. When data leaves your device — only when you send it

Budgetify never moves your data on its own. Some features let **you** deliberately take your data out of the app, and it's important you understand them:

- **Exporting.** You can export your transactions to Excel, CSV, PDF, or text. Android's system file picker asks where you want to save it (for example your Downloads folder or a cloud drive). From that point, the file is under your control, like any other file on your phone.
- **Sharing.** Features such as the Monthly Wrapped card, your gamified profile card, and exports can be shared through Android's standard share sheet. When you choose to share, you select the destination app (for example a messaging or social app), and the content is handed to that app. That destination is outside Budgetify's control and is governed by *its* privacy policy. By default, shareable summaries emphasise percentages rather than exact amounts, and sharing actual figures is an explicit, optional choice.
- **Backups.** An encrypted backup file goes wherever you choose to save it.

In every case, the data leaves only because you asked it to, to a destination you picked.

## 8. Third-party services

Budgetify does **not** embed advertising networks, analytics SDKs, crash-tracking services, social-media trackers, or any other third-party component that collects or transmits your data. The app is self-contained.

## 9. Payments and subscriptions

Budgetify does not process payments itself and never sees your payment details. If Budgetify offers a paid subscription, the purchase is handled **entirely by Google Play**. The app receives only your entitlement status — whether a subscription is currently active — and never your card number, UPI ID, bank details, or billing address. Google's handling of a purchase is governed by [Google's Privacy Policy](https://policies.google.com/privacy).

## 10. Data retention and deletion

Because your data is stored only on your device, **you** control its lifetime:

- Delete individual transactions or other records at any time within the app.
- Clear the app's data from Android Settings to erase everything the app has stored.
- **Uninstalling Budgetify removes its on-device database.** Any export or backup files you created yourself remain wherever you saved them until you delete them.

We hold nothing on our side, so there is nothing for us to delete or return.

## 11. Children's privacy

Budgetify is a general-purpose personal-finance tool intended for a general audience and is not directed at children. Because the app collects no personal data and transmits nothing, it does not knowingly gather information from anyone, including children.

## 12. Your rights and control

Data-protection laws such as India's **Digital Personal Data Protection Act, 2023** and the EU **General Data Protection Regulation (GDPR)** grant rights to access, correct, delete, and port your personal data. Budgetify honours these rights by design: your data never leaves your device, so you already have complete, direct, and exclusive access to it — to view, edit, export, or delete at will — without needing to make a request to us. We hold no copy that could be subject to such a request.

## 13. Changes to this policy

If we update this policy, we will revise the "Effective date" above and publish the new version at this address. Because the app's core design — no internet access, no data collection — is fundamental to what Budgetify is, any change that would weaken these guarantees would be communicated clearly within the app before it takes effect.

## 14. Contact

If you have any questions about this policy or Budgetify's privacy practices, contact:

- **Developer:** [Your name / entity]
- **Email:** [your-contact-email]

---

*Budgetify is offline by design. Your financial life is yours alone — we built the app so it could never be any other way.*
