#!/usr/bin/env python3
"""Measure where Budgetify actually ranks in Play Store search.

ASO advice is worthless without a before/after, and Play Console's own
"search terms" report only shows queries you *already* rank for — which, for a
listing with no keywords in its title, is none. This scrapes the public search
results page instead, so a query we are absent from is visible as absent.

    python3 marketing/playstore/aso_rank.py                  # run + print
    python3 marketing/playstore/aso_rank.py --save out.json  # run + record
    python3 marketing/playstore/aso_rank.py --compare listing/baseline-2026-08-08.json

Play indexes metadata within a day or two but rankings take ~2-4 weeks to
settle, so re-run weekly rather than the morning after a listing change.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import urllib.parse
from datetime import date
from pathlib import Path

PKG = "com.jayrk.budget_tracker"
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0 Safari/537.36")

# Head terms we cannot win yet, long-tail terms we should, and the brand query
# as a canary: if `budgetify` ever stops returning rank 1, something is wrong
# with the listing itself, not with the competition.
QUERIES = [
    # head terms — high volume, dominated by 1M+ install incumbents
    "budget tracker", "expense tracker", "money manager", "budget app",
    "expense manager", "spending tracker", "budget planner",
    # long tail — winnable on metadata alone
    "sms expense tracker", "expense tracker sms", "offline expense tracker",
    "expense tracker without internet", "private expense tracker",
    "expense tracker no ads", "upi expense tracker", "expense tracker india",
    "automatic expense tracker", "offline budget app",
    "expense tracker offline india",
    # brand canary
    "budgetify",
]


def search(query: str, hl: str = "en_IN", gl: str = "IN") -> list[str]:
    """Ordered package names from the first page of Play search results."""
    url = "https://play.google.com/store/search?" + urllib.parse.urlencode(
        {"q": query, "c": "apps", "hl": hl, "gl": gl})
    html = subprocess.run(["curl", "-sL", "-A", UA, url],
                          capture_output=True, text=True).stdout
    order, seen = [], set()
    for m in re.finditer(r"/store/apps/details\?id=([A-Za-z0-9_.]+)", html):
        pkg = m.group(1)
        if pkg not in seen:
            seen.add(pkg)
            order.append(pkg)
    return order


def run(queries: list[str], delay: float = 1.5) -> dict:
    out = {}
    for q in queries:
        results = search(q)
        pos = results.index(PKG) + 1 if PKG in results else None
        out[q] = {"pos": pos, "n": len(results), "top5": results[:5]}
        print(f"  {q:<34} {'—' if pos is None else f'#{pos}':>4}"
              f"   (of {len(results)} results)")
        time.sleep(delay)
    return out


def compare(old: dict, new: dict) -> None:
    def fmt(p):
        return "absent" if p is None else f"#{p}"

    print(f"\n{'query':<34} {'before':>8} {'after':>8}   change")
    print("-" * 66)
    for q in new:
        if q not in old:
            continue
        a, b = old[q].get("pos"), new[q].get("pos")
        if a == b:
            note = "="
        elif a is None:
            note = "NEW — now ranking"
        elif b is None:
            note = "LOST"
        else:
            note = f"{'+' if b < a else ''}{a - b}"
        print(f"{q:<34} {fmt(a):>8} {fmt(b):>8}   {note}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--save", metavar="PATH", help="write results as JSON")
    ap.add_argument("--compare", metavar="PATH",
                    help="diff against an earlier run")
    args = ap.parse_args()

    print(f"Play search rank for {PKG} — {date.today()}\n")
    results = run(QUERIES)

    ranked = [q for q, r in results.items() if r["pos"] is not None]
    print(f"\nranking for {len(ranked)}/{len(results)} queries: "
          f"{', '.join(ranked) or 'none'}")

    if args.save:
        Path(args.save).write_text(json.dumps(results, indent=1),
                                   encoding="utf-8")
        print(f"saved → {args.save}")
    if args.compare:
        compare(json.loads(Path(args.compare).read_text(encoding="utf-8")),
                results)
    return 0


if __name__ == "__main__":
    sys.exit(main())
