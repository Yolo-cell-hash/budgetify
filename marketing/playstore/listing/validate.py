#!/usr/bin/env python3
"""Check every store-listing block in this folder against Play Console's limits.

Play Console silently truncates nothing — it refuses to save an over-length
field, and you find out after you have already lost the draft. Run this first:

    python3 marketing/playstore/listing/validate.py

Exits non-zero if any block is over limit, so it can go in CI.
"""
from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path

# Play Console field limits, in characters.
LIMITS = {"App name": 30, "Short description": 80, "Full description": 4000}

HERE = Path(__file__).parent

# "**App name**" or "## App name  `26/30`" followed by a fenced block.
BLOCK = re.compile(
    r"^(?:\*\*|#+\s*)(App name|Short description|Full description)"
    r"(?:\*\*)?[^\n]*\n+```\n(.*?)\n```",
    re.S | re.M,
)

# A locale heading looks like "## हिन्दी — `hi-IN`" or "# … (en-IN / en-US)".
LOCALE = re.compile(r"^#+ .*?`([a-z]{2}-[A-Z]{2})`", re.M)


def play_len(s: str) -> int:
    """Play counts user-perceived characters, so combining marks are free.

    Devanagari/Tamil/Telugu text is full of combining vowel signs; counting
    code points would over-count a Hindi title by a third and send you
    trimming copy that already fits.
    """
    return sum(1 for ch in s if not unicodedata.combining(ch))


def locale_at(text: str, pos: int) -> str:
    """The nearest locale heading above `pos`."""
    last = "?"
    for m in LOCALE.finditer(text):
        if m.start() > pos:
            break
        last = m.group(1)
    return last


def main() -> int:
    failures = 0
    checked = 0
    for path in sorted(HERE.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        for m in BLOCK.finditer(text):
            field, body = m.group(1), m.group(2)
            limit = LIMITS[field]
            n = play_len(body)
            loc = locale_at(text, m.start())
            checked += 1
            status = "ok " if n <= limit else "OVER"
            if n > limit:
                failures += 1
            line = text[: m.start()].count("\n") + 1
            print(f"{status}  {loc:<6} {field:<17} {n:>4}/{limit}"
                  f"   {path.name}:{line}")
    print()
    if not checked:
        print("no listing blocks found — did the file format change?")
        return 1
    print(f"{checked} blocks checked, {failures} over limit")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
