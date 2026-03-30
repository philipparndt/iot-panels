#!/usr/bin/env python3
"""Check for missing or untranslated strings in Localizable.xcstrings."""

import json
import re
import os
import sys

CATALOG_PATH = "IoTPanels/IoTPanels/Localizable.xcstrings"
SWIFT_DIR = "IoTPanels/IoTPanels"
LANGUAGES = ["de", "fr"]

# Strings that don't need translation (brand names, symbols, format-only)
SKIP_PATTERNS = re.compile(r'^[%@#/+\-–—0-9TVlld:.\s]*$')
BRAND_NAMES = {"IoT Panels", "MQTTAnalyzer", "CocoaMQTT"}

PATTERNS = [
    r'Text\("([^"]+)"\)',
    r'Label\("([^"]+)"',
    r'TextField\("([^"]+)"',
    r'SecureField\("([^"]+)"',
    r'Button\("([^"]+)"\)',
    r'\.navigationTitle\("([^"]+)"\)',
    r'\.searchable\([^)]*prompt:\s*"([^"]+)"',
    r'Tab\("([^"]+)"',
    r'Section\("([^"]+)"\)',
    r'Picker\("([^"]+)"',
    r'ContentUnavailableView\(\s*"([^"]+)"',
    r'LabeledContent\("([^"]+)"',
    r'ProgressView\("([^"]+)"\)',
    r'\.alert\("([^"]+)"',
    r'\.confirmationDialog\("([^"]+)"',
]


def load_catalog():
    with open(CATALOG_PATH, "r") as f:
        return json.load(f)


def scan_swift_strings():
    found = set()
    for root, _, files in os.walk(SWIFT_DIR):
        for fname in files:
            if not fname.endswith(".swift"):
                continue
            with open(os.path.join(root, fname), "r") as f:
                content = f.read()
            for pattern in PATTERNS:
                for match in re.finditer(pattern, content):
                    s = match.group(1)
                    if "\\(" not in s and len(s) >= 2:
                        found.add(s)
    return found


def should_skip(key):
    if not key.strip():
        return True
    if SKIP_PATTERNS.match(key):
        return True
    if key in BRAND_NAMES:
        return True
    if key.startswith("[©"):
        return True
    return False


def main():
    catalog = load_catalog()
    existing_keys = set(catalog.get("strings", {}).keys())
    code_strings = scan_swift_strings()

    errors = 0

    # Check for strings in code but not in catalog
    missing_from_catalog = sorted(code_strings - existing_keys)
    if missing_from_catalog:
        print("Strings in code but NOT in catalog:")
        for s in missing_from_catalog:
            print(f"  + {s}")
            errors += 1
        print()

    # Check for untranslated strings
    for lang in LANGUAGES:
        untranslated = []
        for key, entry in catalog.get("strings", {}).items():
            if should_skip(key):
                continue
            loc = entry.get("localizations", {})
            if lang not in loc or not loc[lang].get("stringUnit", {}).get("value"):
                untranslated.append(key)
        if untranslated:
            print(f"Missing {lang.upper()} translations ({len(untranslated)}):")
            for s in sorted(untranslated):
                print(f"  [{lang}] {s}")
            errors += len(untranslated)
            print()

    if errors == 0:
        print("All translations are complete.")
    else:
        print(f"{errors} issue(s) found.")
        sys.exit(1)


if __name__ == "__main__":
    main()
