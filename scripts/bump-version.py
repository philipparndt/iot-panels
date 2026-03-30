#!/usr/bin/env python3
"""Bump the MARKETING_VERSION in the Xcode project."""

import re
import sys

PROJECT_PATH = "IoTPanels/IoTPanels.xcodeproj/project.pbxproj"


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("major", "minor", "patch"):
        print("Usage: bump-version.py [major|minor|patch]")
        sys.exit(1)

    part = sys.argv[1]

    with open(PROJECT_PATH, "r") as f:
        content = f.read()

    # Find current version
    match = re.search(r"MARKETING_VERSION = (\d+)\.(\d+)\.?(\d*);", content)
    if not match:
        # Try simpler format like "1.0"
        match = re.search(r"MARKETING_VERSION = (\d+)\.(\d+);", content)
        if not match:
            print("Could not find MARKETING_VERSION in project file.")
            sys.exit(1)

    major = int(match.group(1))
    minor = int(match.group(2))
    patch = int(match.group(3)) if match.lastindex >= 3 and match.group(3) else 0

    old_version = f"{major}.{minor}.{patch}"

    if part == "major":
        major += 1
        minor = 0
        patch = 0
    elif part == "minor":
        minor += 1
        patch = 0
    elif part == "patch":
        patch += 1

    new_version = f"{major}.{minor}.{patch}"

    # Replace all occurrences
    content = re.sub(
        r"MARKETING_VERSION = \d+\.\d+\.?\d*;",
        f"MARKETING_VERSION = {new_version};",
        content,
    )

    with open(PROJECT_PATH, "w") as f:
        f.write(content)

    print(f"Version bumped: {old_version} → {new_version}")


if __name__ == "__main__":
    main()
