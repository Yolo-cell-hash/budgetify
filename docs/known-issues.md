# Known issues

Bugs found but not yet fixed, each with enough detail to reproduce without
re-deriving it. One entry per issue. When an issue is fixed, delete its entry
and let the CHANGELOG carry the record instead — this file is a queue, not a
history.

Severity is about what a user loses, not how hard the fix is:

- **High** — wrong numbers, silent data loss, or a wrong result the user is
  unlikely to notice.
- **Medium** — visibly wrong, but obvious enough to work around or undo.
- **Low** — cosmetic, or a rare edge the user can avoid.

---

## KI-001 · Auto-tag rules match on raw substrings, so short names collide

**Severity:** Medium · **Found:** 2026-08-19 · **Area:** `lib/models/transaction_rule_model.dart`

### What's wrong

`TransactionRule.matches()` decides whether a saved rule applies by stripping
every non-alphanumeric character from both names, lower-casing them, and then
testing raw substring containment **in both directions**:

```dart
return normalizedMerchant.contains(normalizedPattern) ||
    normalizedPattern.contains(normalizedMerchant);
```

There is no word boundary and no length floor, so a short string matches
anywhere inside a longer one — including mid-word. `DatabaseService.bulkUpdateByMerchant`
repeats the same test with a lighter normalisation, so "Apply to All Existing"
sweeps the same way.

Both directions misfire, for opposite reasons.

**A short rule pattern claims unrelated longer payees.** Measured:

| Rule taught on | Also fires on |
|---|---|
| `Ola` | `Motorola Service`, `Sola Foods`, `Gola Sweets` |
| `Zo` | `Amazon`, `Bazooka Ltd` |
| `IOB` | `Radiobox` |

**A long rule pattern claims unrelated short payees.** The reverse direction
exists so a rule taught on `Swiggy Instamart` still catches a later `Swiggy`,
which is genuinely wanted — but it has no floor either:

| Rule taught on | Also fires on |
|---|---|
| `Amazon Pay` | `Maz`, `Azo`, `Pay`, `Ama` |
| `Bharat Petroleum` | `Rat`, `Pet`, `Role`, `Bhar` |
| `Olacabs` | `Lac`, `Aca`, `Ac` |

Short payee names are not hypothetical: VPA local parts and initials routinely
produce two- and three-character names (`Ola`, `BP`, `MG`, `KFC`, `Pvr`).

### Reproduce

```dart
// test/zz_repro.dart — flutter test test/zz_repro.dart
final rule = TransactionRule(
  senderName: 'Ola',
  transactionType: TransactionType.debit,
  category: 'Travel',
);
expect(rule.matches('Motorola Service', TransactionType.debit), isFalse); // FAILS — returns true
```

In the app: tag a payment from `Ola` as Travel and choose **Apply to All**.
A later debit whose payee reads `Motorola Service` is auto-tagged Travel.

### Why it wasn't fixed with the 1.75.2 tag-scope work

That change stopped *placeholder* payees (`UPI Transfer`) from ever producing
a rule pattern, which removed the worst instance — a rule stored as the bare
word `transfer`. What remains is short **real** payee names, which is a
pre-existing and independent defect; folding it into that PR would have made
the diff hard to review.

### Fix sketch (not yet agreed)

A length floor alone is not enough — `Ola` is three characters and still hits
`Motorola`. The substring test itself is the problem. Likely shape:

1. Match on token boundaries rather than raw substrings — normalise to a word
   list and require whole-token containment, so `ola` matches `Ola Cabs` but
   not `Motorola`.
2. Keep the reverse direction only when the shorter side is a **prefix run of
   whole tokens** of the longer one (`Swiggy` ⊂ `Swiggy Instamart`), never a
   mid-string fragment.
3. Add a floor (4+ characters) below which only exact normalised equality
   counts, so two-letter payees can never sweep.

Whatever the shape, it needs a corpus test: existing rules users already have
must keep matching what they legitimately matched before, so this cannot be
changed blind.
