#!/usr/bin/env python3
"""
delete_unused_l10n_strings.py

Deletes all unused L10n strings from Strings.swift and all Localizable.strings files for each app language.
- Reads truly_unused_l10n_strings.txt (one per line, e.g. L10n.Section.key)
- Removes the corresponding Swift property from Strings.swift
- Removes the corresponding key from all Localizable.strings files

Usage:
    python3 delete_unused_l10n_strings.py \
        --unused-list CleanUpStrings/truly_unused_l10n_strings.txt \
        --strings-swift Sources/Shared/Resources/Swiftgen/Strings.swift \
        --lproj-root Sources/App/Resources

This script is idempotent and will skip missing keys.
"""
import argparse
import os
import re
from pathlib import Path

parser = argparse.ArgumentParser(description="Delete unused L10n strings from Swift and .strings files.")
parser.add_argument('--unused-list', required=True, help='Path to truly_unused_l10n_strings.txt')
parser.add_argument('--strings-swift', required=True, help='Path to Strings.swift')
parser.add_argument('--lproj-root', required=True, help='Root folder containing *.lproj/Localizable.strings')
args = parser.parse_args()

# 1. Parse unused L10n properties (e.g. L10n.Section.key)
with open(args.unused_list, encoding='utf-8') as f:
    unused_props = [line.strip() for line in f if line.strip() and not line.startswith('#')]

# 2. Convert to Localizable.strings keys (e.g. Section.key)
def l10n_prop_to_key(prop):
    parts = prop.split('.')
    if len(parts) < 3 or parts[0] != 'L10n':
        return None
    return '.'.join(parts[1:])

unused_keys = set(filter(None, (l10n_prop_to_key(p) for p in unused_props)))

# 3. Remove from Strings.swift
with open(args.strings_swift, encoding='utf-8') as f:
    swift_lines = f.readlines()

pattern = re.compile(r'\s*static var (\w+):')

# Find all property names to remove
prop_names = set(k.split('.')[-1] for k in unused_keys)

new_swift_lines = []
skip = False
for line in swift_lines:
    m = pattern.match(line)
    if m and m.group(1) in prop_names:
        skip = True
    if not skip:
        new_swift_lines.append(line)
    # End skipping at end of property (assume next static var or end of struct)
    if skip and (pattern.match(line) or line.strip() == '}'):
        skip = False
        if pattern.match(line):
            new_swift_lines.append(line)

with open(args.strings_swift, 'w', encoding='utf-8') as f:
    f.writelines(new_swift_lines)

# 4. Remove from all Localizable.strings
lproj_root = Path(args.lproj_root)
for lproj in lproj_root.glob('*.lproj'):
    strings_path = lproj / 'Localizable.strings'
    if not strings_path.exists():
        continue
    with open(strings_path, encoding='utf-8') as f:
        lines = f.readlines()
    new_lines = []
    for line in lines:
        # Match key = "value";
        m = re.match(r'\s*"([^"]+)"\s*=.*', line)
        if m and m.group(1) in unused_keys:
            continue
        new_lines.append(line)
    with open(strings_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

print(f"Removed {len(unused_keys)} unused L10n keys from Strings.swift and all Localizable.strings files.")
