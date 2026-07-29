#!/usr/bin/env python3
"""Regenerate `lib/services/bank_directory_data.dart` from `list_of_banks.txt`.

`list_of_banks.txt` is the TRAI/DLT sender-header registry: a JSON map of
header -> registered entity name, as filed by the banks. The names in it are
filing names, not brand names ("HDFC BANK LIMITED", "The Hongkong & Shanghai
Banking Corporation Limited"), and the same bank files under many headers
(State Bank of India alone has 273).

This script collapses that into what the app actually needs: one display name
per bank, with every header that resolves to it. Filing names are cleaned by
rule (title case, suffix stripping, an acronym allowlist); the banks users
are most likely to hold accounts with get a curated brand name instead, since
no rule turns "The Hongkong & Shanghai Banking Corporation Limited" into
"HSBC".

Usage (from the repo root):  python tool/gen_bank_directory.py
"""

import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "list_of_banks.txt"
TARGET = ROOT / "lib" / "services" / "bank_directory_data.dart"

# Tokens that stay uppercase through title-casing.
ACRONYMS = {
    "SBI", "HDFC", "ICICI", "IDBI", "IDFC", "RBL", "UCO", "IOB", "DCB", "AU",
    "ESAF", "TJSB", "SVC", "NKGSB", "GP", "UP", "MP", "AP", "HP", "JK", "NA",
    "PNB", "BOI", "BOB", "CSB", "IDFCFIRST", "NSDL", "IPPB", "USA", "UK",
    "PSU", "II", "III", "IV", "DCC", "PDCC", "ADCC", "KDCC",
    "TDCC", "SDCC", "BDCC", "VDCC", "CKP", "GS", "SBS", "NCC", "AMCO",
}

# Words that stay lowercase inside a name (never as the first word).
SMALL_WORDS = {"of", "and", "the", "for", "in", "at", "on", "de", "da"}

# Filing name (normalised, see `group_key`) -> brand name. Curated for the
# banks a typical user actually banks with; everything else is title-cased.
CURATED = {
    "STATE BANK OF INDIA": "State Bank of India",
    "HDFC BANK": "HDFC Bank",
    "ICICI BANK": "ICICI Bank",
    "AXIS BANK": "Axis Bank",
    "BANK OF INDIA": "Bank of India",
    "BANK OF BARODA": "Bank of Baroda",
    "BANK OF MAHARASHTRA": "Bank of Maharashtra",
    "PUNJAB NATIONAL BANK": "Punjab National Bank",
    "KOTAK MAHINDRA BANK": "Kotak Mahindra Bank",
    "IDFC FIRST BANK": "IDFC FIRST Bank",
    "IDBI BANK": "IDBI Bank",
    "CANARA BANK": "Canara Bank",
    "UNION BANK OF INDIA": "Union Bank of India",
    "UNITED BANK OF INDIA": "United Bank of India",
    "INDIAN BANK": "Indian Bank",
    "INDIAN OVERSEAS BANK": "Indian Overseas Bank",
    "CENTRAL BANK OF INDIA": "Central Bank of India",
    "UCO BANK": "UCO Bank",
    "YES BANK": "YES Bank",
    "RBL BANK": "RBL Bank",
    "INDUSIND BANK": "IndusInd Bank",
    "FEDERAL BANK": "Federal Bank",
    "SOUTH INDIAN BANK": "South Indian Bank",
    "KARNATAKA BANK": "Karnataka Bank",
    "KARUR VYSYA BANK": "Karur Vysya Bank",
    "CITY UNION BANK": "City Union Bank",
    "TAMILNAD MERCANTILE BANK": "Tamilnad Mercantile Bank",
    "DHANLAXMI BANK": "Dhanlaxmi Bank",
    "DCB BANK": "DCB Bank",
    "BANDHAN BANK": "Bandhan Bank",
    "CSB BANK": "CSB Bank",
    "CATHOLIC SYRIAN BANK": "CSB Bank",
    "JAMMU AND KASHMIR BANK": "J&K Bank",
    "PUNJAB AND SIND BANK": "Punjab & Sind Bank",
    "PUNJAB & SIND BANK": "Punjab & Sind Bank",
    "ORIENTAL BANK OF COMMERCE": "Oriental Bank of Commerce",
    "SYNDICATE BANK": "Syndicate Bank",
    "ALLAHABAD BANK": "Allahabad Bank",
    "CORPORATION BANK": "Corporation Bank",
    "ANDHRA BANK": "Andhra Bank",
    "VIJAYA BANK": "Vijaya Bank",
    "DENA BANK": "Dena Bank",
    # Foreign banks.
    "HONGKONG & SHANGHAI BANKING CORPORATION": "HSBC",
    "HONGKONG AND SHANGHAI BANKING CORPORATION": "HSBC",
    "AMERICAN EXPRESS BANKING CORP": "American Express",
    "STANDARD CHARTERED BANK": "Standard Chartered",
    "CITI BANK": "Citibank",
    "CITIBANK": "Citibank",
    "CITIBANK NA": "Citibank",
    "DBS BANK INDIA": "DBS Bank",
    "DEUTSCHE BANK": "Deutsche Bank",
    "BARCLAYS BANK": "Barclays",
    "BANK OF AMERICA": "Bank of America",
    # Payments / small finance banks.
    "PAYTM PAYMENTS BANK": "Paytm Payments Bank",
    "AIRTEL PAYMENTS BANK": "Airtel Payments Bank",
    "INDIA POST PAYMENTS BANK": "India Post Payments Bank",
    "FINO PAYMENTS BANK": "Fino Payments Bank",
    "JIO PAYMENTS BANK": "Jio Payments Bank",
    "NSDL PAYMENTS BANK": "NSDL Payments Bank",
    "AU SMALL FINANCE BANK": "AU Small Finance Bank",
    "ESAF SMALL FINANCE BANK": "ESAF Small Finance Bank",
    "EQUITAS SMALL FINANCE BANK": "Equitas Small Finance Bank",
    "UJJIVAN SMALL FINANCE BANK": "Ujjivan Small Finance Bank",
    "JANA SMALL FINANCE BANK": "Jana Small Finance Bank",
    "FINCARE SMALL FINANCE BANK": "Fincare Small Finance Bank",
    "SURYODAY SMALL FINANCE BANK": "Suryoday Small Finance Bank",
    "UTKARSH SMALL FINANCE BANK": "Utkarsh Small Finance Bank",
    "NORTH EAST SMALL FINANCE BANK": "North East Small Finance Bank",
    "SHIVALIK SMALL FINANCE BANK": "Shivalik Small Finance Bank",
    "UNITY SMALL FINANCE BANK": "Unity Small Finance Bank",
    "CAPITAL SMALL FINANCE BANK": "Capital Small Finance Bank",
}

SUFFIXES = re.compile(
    r"\s*\b(?:PRIVATE\s+)?(?:LIMITED|LTD|LTDS|PVT|INC|CORP|CORPN)\b\.?\s*$",
    re.IGNORECASE,
)

# The registry also drops "LTD" mid-name ("… Bank Ltd Kolhapur"), where the
# suffix rule can't reach it.
INLINE_LTD = re.compile(r"\s*\b(?:LIMITED|LTD|PVT|PRIVATE)\b\.?(?=\s)",
                        re.IGNORECASE)


def group_key(name: str) -> str:
    """Normalise a filing name so casing/suffix variants of one bank merge."""
    key = name.upper().replace(".", " ").replace(",", " ")
    key = re.sub(r"\s+", " ", key).strip()
    # Co-operative spelling zoo -> one form.
    key = re.sub(r"\bCO\s*[- ]?\s*OPERATIVE\b", "COOPERATIVE", key)
    key = re.sub(r"\bCO\s*[- ]?\s*OP\b", "COOPERATIVE", key)
    key = re.sub(r"\bCOOP\b", "COOPERATIVE", key)
    key = re.sub(r"\bSAHKARI\b", "SAHAKARI", key)
    while True:
        stripped = SUFFIXES.sub("", key).strip()
        if stripped == key:
            break
        key = stripped
    if key.startswith("THE "):
        key = key[4:]
    return re.sub(r"\s+", " ", key).strip()


def title_case(name: str) -> str:
    """Best-effort brand-ish rendering of a filing name."""
    cleaned = name.replace(".", " ").replace(",", " ")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    while True:
        stripped = SUFFIXES.sub("", cleaned).strip()
        if stripped == cleaned:
            break
        cleaned = stripped
    cleaned = re.sub(r"\bCo\s*[- ]?\s*Operative\b", "Co-operative", cleaned,
                     flags=re.IGNORECASE)
    cleaned = re.sub(r"\bCo\s*[- ]?\s*Op\b", "Co-operative", cleaned,
                     flags=re.IGNORECASE)
    cleaned = re.sub(r"\bCooperative\b", "Co-operative", cleaned,
                     flags=re.IGNORECASE)
    cleaned = INLINE_LTD.sub("", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    def cap(token: str) -> str:
        return token.upper() if token.upper() in ACRONYMS else token.capitalize()

    words = []
    for i, word in enumerate(cleaned.split(" ")):
        if word.upper() in ACRONYMS:
            words.append(word.upper())
        elif word.lower() in SMALL_WORDS and i > 0:
            words.append(word.lower())
        elif "-" in word:
            # "CO-OPERATIVE" -> "Co-operative": only the first part is a word
            # boundary users read as capitalised.
            head, *rest = word.split("-")
            words.append("-".join([cap(head)] + [p.lower() for p in rest]))
        else:
            words.append(cap(word))
    out = " ".join(w for w in words if w)
    return out or name


def display_name(filing_name: str) -> str:
    key = group_key(filing_name)
    return CURATED.get(key) or title_case(filing_name)


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", r"\'") + "'"


def main() -> None:
    registry = json.loads(SOURCE.read_text(encoding="utf-8"))

    by_bank: dict[str, set[str]] = defaultdict(set)
    for header, filing_name in registry.items():
        header = header.strip().upper()
        if not header:
            continue
        by_bank[display_name(filing_name.strip())].add(header)

    lines = [
        "// GENERATED FILE — do not edit by hand.",
        "//",
        "// Regenerate with `python tool/gen_bank_directory.py`, which reads the",
        "// DLT sender-header registry in `list_of_banks.txt` and collapses its",
        "// filing names into one display name per bank. See BankDirectory in",
        "// `bank_directory.dart` for how a sender is resolved against this.",
        "library;",
        "",
        "/// Display name -> every DLT sender header registered to that bank.",
        "///",
        f"/// {len(by_bank)} banks across {len(registry)} headers.",
        "const Map<String, List<String>> kHeadersByBank = {",
    ]
    for bank in sorted(by_bank):
        headers = sorted(by_bank[bank])
        joined = ", ".join(dart_string(h) for h in headers)
        entry = f"  {dart_string(bank)}: [{joined}],"
        if len(entry) <= 80:
            lines.append(entry)
        else:
            lines.append(f"  {dart_string(bank)}: [")
            current = "   "
            for header in headers:
                piece = f" {dart_string(header)},"
                if len(current) + len(piece) > 79:
                    lines.append(current)
                    current = "   "
                current += piece
            if current.strip():
                lines.append(current)
            lines.append("  ],")
    lines.append("};")
    lines.append("")

    TARGET.write_text("\n".join(lines), encoding="utf-8")
    print(f"{TARGET.relative_to(ROOT)}: {len(by_bank)} banks, "
          f"{len(registry)} headers")


if __name__ == "__main__":
    main()
