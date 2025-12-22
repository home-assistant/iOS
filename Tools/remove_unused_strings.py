#!/usr/bin/env python3
"""
Remove unused localization strings from the Home Assistant iOS app.

This script:
1. Uses detect_unused_strings.py to find unused strings
2. Removes them from all language Localizable.strings files
3. Regenerates Strings.swift using SwiftGen
"""

import re
import subprocess
import sys
from pathlib import Path
from typing import List, Set

# Import the detection module
sys.path.insert(0, str(Path(__file__).parent))
from detect_unused_strings import find_unused_strings, L10nString


def get_all_localizable_files(repo_root: Path) -> List[Path]:
    """Find all Localizable.strings files across all language directories."""
    resources_dir = repo_root / "Sources/App/Resources"
    localizable_files = []
    
    for lproj_dir in resources_dir.glob("*.lproj"):
        localizable_file = lproj_dir / "Localizable.strings"
        if localizable_file.exists():
            localizable_files.append(localizable_file)
    
    return sorted(localizable_files)


def remove_key_from_strings_file(strings_file: Path, key_to_remove: str) -> bool:
    """
    Remove a specific key from a .strings file.
    Returns True if the key was found and removed, False otherwise.
    """
    try:
        with open(strings_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Pattern to match the key-value pair
        # Example: "key.name" = "value";
        # The value is a quoted string that may contain escaped quotes
        pattern = rf'^"{re.escape(key_to_remove)}" = "(?:[^"\\]|\\.)*";$'
        
        lines = content.split('\n')
        new_lines = []
        removed = False
        
        for line in lines:
            if re.match(pattern, line.strip()):
                removed = True
                print(f"  Removed from {strings_file.parent.name}: {key_to_remove}")
            else:
                new_lines.append(line)
        
        if removed:
            # Write back the modified content
            new_content = '\n'.join(new_lines)
            with open(strings_file, 'w', encoding='utf-8') as f:
                f.write(new_content)
        
        return removed
    
    except Exception as e:
        print(f"Error processing {strings_file}: {e}", file=sys.stderr)
        return False


def regenerate_strings_swift(repo_root: Path) -> bool:
    """Regenerate Strings.swift using SwiftGen."""
    try:
        print("\nRegenerating Strings.swift using SwiftGen...")
        result = subprocess.run(
            ['./Pods/SwiftGen/bin/swiftgen'],
            cwd=repo_root,
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print(f"Error running SwiftGen: {result.stderr}", file=sys.stderr)
            return False
        
        print("✅ Strings.swift regenerated successfully")
        return True
    
    except Exception as e:
        print(f"Error regenerating Strings.swift: {e}", file=sys.stderr)
        return False


def main():
    """Main entry point for the script."""
    # Determine repository root
    repo_root = Path(__file__).parent.parent
    
    # Path to Strings.swift
    strings_swift_path = repo_root / "Sources/Shared/Resources/Swiftgen/Strings.swift"
    
    if not strings_swift_path.exists():
        print(f"Error: Strings.swift not found at {strings_swift_path}", file=sys.stderr)
        sys.exit(1)
    
    # Find unused strings
    print("Detecting unused strings...")
    unused_strings = find_unused_strings(repo_root, strings_swift_path)
    
    if not unused_strings:
        print("\n✅ No unused strings found - nothing to remove!")
        sys.exit(0)
    
    print(f"\n{'='*80}")
    print(f"Found {len(unused_strings)} unused strings to remove")
    print(f"{'='*80}\n")
    
    # Get all Localizable.strings files
    localizable_files = get_all_localizable_files(repo_root)
    print(f"Found {len(localizable_files)} Localizable.strings files\n")
    
    # Extract the keys to remove
    keys_to_remove = {unused.localizable_key for unused in unused_strings}
    
    # Remove keys from all Localizable.strings files
    total_removals = 0
    for key in sorted(keys_to_remove):
        print(f"\nRemoving key: {key}")
        for strings_file in localizable_files:
            if remove_key_from_strings_file(strings_file, key):
                total_removals += 1
    
    print(f"\n{'='*80}")
    print(f"Removed {total_removals} key-value pairs across all language files")
    print(f"{'='*80}\n")
    
    # Regenerate Strings.swift
    if not regenerate_strings_swift(repo_root):
        print("\n⚠️  Warning: Failed to regenerate Strings.swift", file=sys.stderr)
        sys.exit(1)
    
    print("\n✅ Successfully removed unused strings and regenerated Strings.swift")
    print("\nPlease review the changes and commit them.")
    sys.exit(0)


if __name__ == "__main__":
    main()
