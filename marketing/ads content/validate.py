#!/usr/bin/env python3
"""Check every ad line in copy.md against Google Ads' field limits.

    python3 validate.py

Google truncates silently in some surfaces and rejects in others, so an
over-length line is not something you want to discover from the asset report
three days into a flight. Mirrors marketing/playstore/listing/validate.py.
"""

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
COPY = HERE / "copy.md"

# Google Ads App campaign field limits.
LIMITS = {"headline": 30, "description": 90}

# Fenced blocks in copy.md are either headlines or descriptions; the nearest
# preceding heading says which.
HEADING = re.compile(r"^#{2,3}\s+(.*)$")
FENCE = re.compile(r"^```\s*$")


def kind_of(heading: str) -> str | None:
    h = heading.lower()
    if "headline" in h:
        return "headline"
    if "description" in h:
        return "description"
    return None


def main() -> int:
    if not COPY.exists():
        print(f"missing {COPY}")
        return 1

    kind = None
    in_fence = False
    failures = 0
    counts = {"headline": 0, "description": 0}

    for lineno, raw in enumerate(COPY.read_text().splitlines(), 1):
        if m := HEADING.match(raw):
            if not in_fence:
                kind = kind_of(m.group(1)) or kind
            continue
        if FENCE.match(raw):
            in_fence = not in_fence
            continue
        if not in_fence or not raw.strip() or kind is None:
            continue

        line = raw.rstrip()
        limit = LIMITS[kind]
        n = len(line)
        counts[kind] += 1
        flag = "  <-- OVER" if n > limit else ""
        if n > limit:
            failures += 1
        print(f"{kind[:4]}  {n:>3}/{limit}  {line}{flag}")

    print()
    print(f"{counts['headline']} headlines, {counts['description']} descriptions")
    if failures:
        print(f"FAIL — {failures} line(s) over the limit")
        return 1
    print("OK — every line fits")
    return 0


if __name__ == "__main__":
    sys.exit(main())
