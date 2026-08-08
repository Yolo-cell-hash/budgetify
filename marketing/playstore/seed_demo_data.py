#!/usr/bin/env python3
"""Seed a Budgetify install with a believable demo dataset for store screenshots.

The Play Store listing has to show a *lived-in* app: months of history so the
trend chart has a shape, a savings rate that isn't a dash, a net worth that
isn't zero. A fresh install shows none of that, so the old listing screenshots
led with "₹517.00 spent" and "No income recorded this month".

This writes directly into a copy of the app's own SQLite file (schema v32) at
the paths the app already uses, so every number on screen is computed by the
real app from real rows -- nothing in the screenshots is mocked up.

Usage:
    python3 seed_demo_data.py <path-to-budget_tracker.db>

Persona: a salaried Bengaluru professional on ~Rs 95,000/month take-home.
Amounts and merchants are ordinary Indian ones so the listing reads as real.
"""

from __future__ import annotations

import random
import sqlite3
import sys
from datetime import date, datetime, timedelta

# Deterministic: the same seed run twice yields byte-identical screenshots.
random.seed(20260808)

TODAY = date(2026, 8, 8)
SALARY = 95_000.0
ACCOUNT = "XX829"

CREDIT, DEBIT = 0, 1  # TransactionType.index

# ---------------------------------------------------------------------------
# The monthly rhythm. (day, merchant, amount, category, sender_bank, kind)
# `kind` picks the SMS phrasing so the message text matches how that bank
# actually writes it -- the parser's own output is what shows in the UI.
# ---------------------------------------------------------------------------
MONTHLY = [
    # day, merchant,            amount,  category,             bank,    kind
    (1, "ZENTRIX LABS", SALARY, "Salary", "ICICI", "salary"),
    (2, "Rent", 18_000.0, "Bills & Utilities", "ICICI", "neft"),
    (2, "Cult.fit", 1_500.0, "Health & Medical", "HDFC", "card"),
    (3, "Swiggy", 549.0, "Food & Dining", "ICICI", "upi"),
    (3, "Uber", 220.0, "Transportation", "ICICI", "upi"),
    (4, "BigBasket", 3_200.0, "Groceries", "HDFC", "card"),
    (5, "Netflix", 649.0, "Entertainment", "HDFC", "card"),
    (5, "Spotify", 149.0, "Entertainment", "HDFC", "card"),
    (5, "Axis Bluechip Fund", 15_000.0, "Investments", "ICICI", "neft"),
    (6, "Amazon", 1_299.0, "Shopping", "ICICI", "upi"),
    (7, "BESCOM", 1_850.0, "Bills & Utilities", "ICICI", "upi"),
    (8, "Zomato", 432.0, "Food & Dining", "ICICI", "upi"),
    (8, "Third Wave Coffee", 380.0, "Food & Dining", "HDFC", "card"),
    (9, "Uber", 310.0, "Transportation", "ICICI", "upi"),
    (10, "Jio", 399.0, "Bills & Utilities", "ICICI", "upi"),
    (10, "Namma Metro", 90.0, "Transportation", "ICICI", "upi"),
    (11, "Blinkit", 640.0, "Groceries", "ICICI", "upi"),
    (12, "ACT Broadband", 999.0, "Bills & Utilities", "HDFC", "card"),
    (12, "DMart", 2_850.0, "Groceries", "HDFC", "card"),
    (13, "Myntra", 2_150.0, "Shopping", "HDFC", "card"),
    (14, "Indian Oil", 2_500.0, "Transportation", "HDFC", "card"),
    (14, "Apollo Pharmacy", 680.0, "Health & Medical", "ICICI", "upi"),
    (15, "Swiggy", 680.0, "Food & Dining", "ICICI", "upi"),
    (15, "LIC Premium", 2_400.0, "Other", "ICICI", "neft"),
    (16, "Indane Gas", 950.0, "Bills & Utilities", "ICICI", "upi"),
    (16, "BookMyShow", 700.0, "Entertainment", "HDFC", "card"),
    (18, "Ola", 280.0, "Transportation", "ICICI", "upi"),
    (19, "Zomato", 520.0, "Food & Dining", "ICICI", "upi"),
    (20, "Toit", 2_100.0, "Food & Dining", "HDFC", "card"),
    (21, "Decathlon", 1_899.0, "Shopping", "HDFC", "card"),
    (23, "PVR Cinemas", 480.0, "Entertainment", "HDFC", "card"),
    (24, "Blinkit", 520.0, "Groceries", "ICICI", "upi"),
    (25, "Uber", 340.0, "Transportation", "ICICI", "upi"),
    (26, "BigBasket", 2_900.0, "Groceries", "HDFC", "card"),
    (26, "1mg", 420.0, "Health & Medical", "ICICI", "upi"),
    (27, "Swiggy", 495.0, "Food & Dining", "ICICI", "upi"),
    (28, "Amazon", 899.0, "Shopping", "ICICI", "upi"),
    (28, "Rapido", 120.0, "Transportation", "ICICI", "upi"),
    (29, "Chai Point", 180.0, "Food & Dining", "HDFC", "card"),
]

# One-offs that give each month its own silhouette, so the trend line and the
# month-over-month comparison have something true to say.
ONE_OFFS = [
    (date(2026, 4, 17), "IRCTC", 1_450.0, "Travel", "ICICI", "upi"),
    (date(2026, 4, 22), "Croma", 4_499.0, "Shopping", "HDFC", "card"),
    (date(2026, 5, 9), "MakeMyTrip", 8_900.0, "Travel", "HDFC", "card"),
    (date(2026, 5, 21), "Barbeque Nation", 2_480.0, "Food & Dining", "HDFC", "card"),
    (date(2026, 6, 6), "Freelance - Kavi Studio", 12_000.0, "Salary", "ICICI", "salary"),
    (date(2026, 6, 14), "Apollo Hospitals", 3_200.0, "Health & Medical", "ICICI", "upi"),
    (date(2026, 6, 27), "Goa Homestay", 6_400.0, "Travel", "HDFC", "card"),
    (date(2026, 7, 4), "Titan", 5_999.0, "Shopping", "HDFC", "card"),
    (date(2026, 7, 19), "Udemy", 1_299.0, "Education", "HDFC", "card"),
    (date(2026, 7, 26), "Nandhana Palace", 1_680.0, "Food & Dining", "ICICI", "upi"),
]

SENDERS = {"ICICI": "AD-ICICIB-S", "HDFC": "VM-HDFCBK-S"}


def sms_text(kind: str, bank: str, merchant: str, amount: float, when: date) -> str:
    """Compose the bank SMS this row would have been read from."""
    amt = f"{amount:,.2f}"
    d = when.strftime("%d-%b-%y")
    if kind == "salary":
        return (
            f"{bank} Bank Acct {ACCOUNT} credited with Rs {amt} on {d}. "
            f"Info: SALARY-{merchant.upper()}. Avl Bal Rs {random.randint(60, 140) * 1000:,}.00."
        )
    if kind == "upi":
        return (
            f"{bank} Bank Acct {ACCOUNT} debited for Rs {amt} on {d}; "
            f"{merchant} credited. UPI:{random.randint(10**11, 10**12 - 1)}."
        )
    if kind == "card":
        return (
            f"Rs {amt} spent on {bank} Bank Card x{random.randint(1000, 9999)} "
            f"at {merchant} on {d}. Avl Lmt Rs {random.randint(40, 90) * 1000:,}.00."
        )
    # neft
    return (
        f"{bank} Bank Acct {ACCOUNT} debited Rs {amt} on {d} towards "
        f"{merchant}. Ref NEFT{random.randint(10**8, 10**9 - 1)}."
    )


def parse_label(kind: str, bank: str) -> str:
    return {
        "salary": f"{bank} · salary credit",
        "upi": f"{bank} · UPI transfer-out",
        "card": f"{bank} · card spend",
        "neft": f"{bank} · NEFT debit",
    }[kind]


def months_to_seed() -> list[tuple[int, int]]:
    """April through the current month of 2026."""
    return [(2026, m) for m in range(4, TODAY.month + 1)]


def build_rows() -> list[tuple]:
    rows: list[tuple] = []
    seen: set[str] = set()

    def add(when: date, merchant, amount, category, bank, kind):
        if when > TODAY:
            return
        ttype = CREDIT if category == "Salary" else DEBIT
        # Spread entries through the working day so "Recent Transactions"
        # and the daily curve don't all stack on midnight.
        stamp = datetime(
            when.year, when.month, when.day,
            random.randint(8, 21), random.randint(0, 59),
        )
        fp = f"{amount:.2f}|{ttype}|{bank}|{merchant}|{when.isoformat()}"
        if fp in seen:
            return
        seen.add(fp)
        rows.append((
            amount, ttype, SENDERS[bank],
            sms_text(kind, bank, merchant, amount, when),
            int(stamp.timestamp() * 1000),
            1,                      # is_classified
            category,
            None,                   # notes
            f"{bank} {ACCOUNT}",    # account_info
            None if kind == "salary" else merchant,
            0,                      # is_manual
            fp,
            None, None,             # split_share, review_reasons
            parse_label(kind, bank),
            None,                   # tax_bucket
        ))

    for year, month in months_to_seed():
        for day, merchant, amount, category, bank, kind in MONTHLY:
            try:
                when = date(year, month, day)
            except ValueError:
                continue
            # +/-8% jitter on discretionary spend so no two months are clones.
            amt = amount
            if category not in ("Salary", "Investments") and merchant != "Rent":
                amt = round(amount * random.uniform(0.92, 1.08), 0)
            add(when, merchant, amt, category, bank, kind)

    for when, merchant, amount, category, bank, kind in ONE_OFFS:
        add(when, merchant, amount, category, bank, kind)

    return rows


HOLDINGS = [
    ("EPF", "asset", "PPF / EPF", 420_000.0),
    ("Axis Bluechip Fund", "asset", "Mutual Fund", 385_000.0),
    ("ICICI Savings", "asset", "Savings", 145_000.0),
    ("HDFC Fixed Deposit", "asset", "Fixed Deposit", 200_000.0),
    ("Sovereign Gold Bond", "asset", "Gold", 95_000.0),
    ("Zerodha Portfolio", "asset", "Stocks", 110_000.0),
    ("Car Loan", "liability", "Car Loan", 280_000.0),
    ("HDFC Credit Card", "liability", "Credit Card", 42_000.0),
]

BUDGETS = [
    ("Monthly Budget", 70_000.0, None),
    ("Food & Dining", 8_000.0, "Food & Dining"),
    ("Groceries", 12_000.0, "Groceries"),
    ("Transportation", 6_000.0, "Transportation"),
    ("Shopping", 7_000.0, "Shopping"),
    ("Entertainment", 2_500.0, "Entertainment"),
]

RECURRING = [
    ("Rent", "Bills & Utilities", 18_000.0, 2),
    ("Cult.fit", "Health & Medical", 1_500.0, 2),
    ("Netflix", "Entertainment", 649.0, 5),
    ("Spotify", "Entertainment", 149.0, 5),
    ("Jio", "Bills & Utilities", 399.0, 10),
    ("ACT Broadband", "Bills & Utilities", 999.0, 12),
    ("LIC Premium", "Other", 2_400.0, 15),
]

GOALS = [
    ("Goa Trip", "\U0001F3D6", 60_000.0, 38_500.0, date(2026, 12, 20)),
    ("MacBook Pro", "\U0001F4BB", 150_000.0, 42_000.0, date(2027, 3, 1)),
    ("Emergency Fund", "\U0001F6E1", 300_000.0, 185_000.0, None),
]


def ms(d: date) -> int:
    return int(datetime(d.year, d.month, d.day, 10, 0).timestamp() * 1000)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    db = sqlite3.connect(sys.argv[1])

    # Clear whatever the emulator's stock SMS inbox produced -- those rows are
    # dated randomly and half-classified, which is exactly what we don't want
    # on a store page.
    for table in (
        "transactions", "budgets", "holdings", "recurring_payments",
        "recurring_charges", "savings_goals", "goal_contributions",
        "net_worth_snapshots", "deleted_transactions",
    ):
        db.execute(f"DELETE FROM {table}")

    rows = build_rows()
    db.executemany(
        """INSERT INTO transactions(
               amount, type, sender, message, detected_at, is_classified,
               category, notes, account_info, merchant_name, is_manual,
               fingerprint, split_share, review_reasons, parse_source, tax_bucket)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        rows,
    )

    start = date(2026, 4, 1).isoformat()
    db.executemany(
        """INSERT INTO budgets(name, amount, period, category, start_date)
           VALUES (?,?,'monthly',?,?)""",
        [(n, a, c, start) for n, a, c in BUDGETS],
    )

    now = int(datetime.now().timestamp() * 1000)
    db.executemany(
        """INSERT INTO holdings(name, kind, category, amount, note, updated_at)
           VALUES (?,?,?,?,NULL,?)""",
        [(n, k, c, a, now) for n, k, c, a in HOLDINGS],
    )

    db.executemany(
        """INSERT INTO recurring_payments(
               name, category, amount, amount_is_fixed, cadence, day_of_month,
               anchor_date, auto_match, reminder_lead_days, paused, created_at)
           VALUES (?,?,?,1,'monthly',?,?,1,2,0,?)""",
        [(n, c, a, d, ms(date(2026, 4, d)), now) for n, c, a, d in RECURRING],
    )

    for i, (name, emoji, target, saved, deadline) in enumerate(GOALS, start=1):
        db.execute(
            """INSERT INTO savings_goals(
                   id, name, emoji, target_amount, deadline, accent, note,
                   created_at, completed_at, archived)
               VALUES (?,?,?,?,?,?,NULL,?,NULL,0)""",
            (i, name, emoji, target, ms(deadline) if deadline else None,
             i - 1, ms(date(2026, 4, 1))),
        )
        # Fund each goal in monthly instalments rather than one lump, so the
        # goal detail screen has a contribution history to draw.
        n = 4
        each = round(saved / n, 2)
        for k in range(n):
            when = date(2026, 4 + k, 6)
            db.execute(
                "INSERT INTO goal_contributions(goal_id, amount, date, note) "
                "VALUES (?,?,?,NULL)",
                (i, each if k < n - 1 else round(saved - each * (n - 1), 2), ms(when)),
            )

    db.commit()
    spend = db.execute(
        "SELECT COALESCE(SUM(amount),0) FROM transactions WHERE type=1 "
        "AND category NOT IN ('Investments','Self Transfer','Settlement') "
        "AND detected_at >= ?", (ms(date(2026, TODAY.month, 1)),),
    ).fetchone()[0]
    print(f"seeded {len(rows)} transactions across {len(months_to_seed())} months")
    print(f"current-month spend: Rs {spend:,.0f}")
    db.close()


if __name__ == "__main__":
    main()
