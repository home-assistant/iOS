#!/usr/bin/env python3
"""
Detect unused localization strings in the Home Assistant iOS app.

This script:
1. Parses Strings.swift to extract all L10n properties and their corresponding Localizable keys
2. Checks for usage of L10n properties in Swift source code
3. Double-checks for direct usage of Localizable keys in the codebase
4. Reports unused strings that can be safely removed
"""

import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple, NamedTuple


class EnumContext(NamedTuple):
    """Represents an enum in the stack with its name and indentation level."""
    name: str
    indent: int


class L10nString:
    """Represents a localized string with its L10n property path and Localizable key."""
    
    def __init__(self, swift_property: str, localizable_key: str, line_number: int):
        self.swift_property = swift_property
        self.localizable_key = localizable_key
        self.line_number = line_number
    
    def __repr__(self):
        return f"L10nString({self.swift_property} -> {self.localizable_key})"


def parse_strings_swift(strings_swift_path: Path) -> List[L10nString]:
    """
    Parse Strings.swift to extract all L10n properties and their Localizable keys.
    
    Returns a list of L10nString objects containing the Swift property path and 
    corresponding Localizable key.
    """
    with open(strings_swift_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    l10n_strings = []
    
    # Track the current enum path (e.g., ["About", "Beta"])
    enum_stack = []
    
    for i, line in enumerate(lines, start=1):
        # Track enum declarations to build the property path
        enum_match = re.search(r'public enum (\w+)', line)
        if enum_match:
            enum_name = enum_match.group(1)
            # Skip the root L10n enum
            if enum_name == 'L10n' and not enum_stack:
                continue
            # Calculate indentation level
            indent = len(line) - len(line.lstrip())
            # Pop enums from stack if we're at the same or lower indentation
            while enum_stack and enum_stack[-1].indent >= indent:
                enum_stack.pop()
            enum_stack.append(EnumContext(enum_name, indent))
            continue
        
        # Detect closing braces that end enum blocks
        if re.match(r'\s*}', line):
            # Pop the last enum if there's significant dedent
            indent = len(line) - len(line.lstrip())
            while enum_stack and enum_stack[-1].indent >= indent:
                enum_stack.pop()
            continue
        
        # Match static var declarations with L10n.tr() calls
        # Pattern: public static var propertyName: String { return L10n.tr("Localizable", "key") }
        static_var_match = re.search(
            r'public static var (\w+):\s*String\s*\{\s*return L10n\.tr\("Localizable",\s*"([^"]+)"\)',
            line
        )
        if static_var_match:
            property_name = static_var_match.group(1)
            localizable_key = static_var_match.group(2)
            
            # Build the full property path
            path_parts = [e.name for e in enum_stack] + [property_name]
            # SwiftGen creates nested enums but access is L10n.EnumName.property
            # So we just join with dots, no need to convert first to lowercase
            swift_property = '.'.join(path_parts)
            
            l10n_strings.append(L10nString(swift_property, localizable_key, i))
            continue
        
        # Match static func declarations with L10n.tr() calls (for parameterized strings)
        # Pattern: public static func funcName(_ p1: Any) -> String { return L10n.tr("Localizable", "key", ...) }
        static_func_match = re.search(
            r'public static func (\w+)\([^)]*\)\s*->\s*String\s*\{[^}]*L10n\.tr\("Localizable",\s*"([^"]+)"',
            line
        )
        if static_func_match:
            func_name = static_func_match.group(1)
            localizable_key = static_func_match.group(2)
            
            # Build the full property path
            path_parts = [e.name for e in enum_stack] + [func_name]
            swift_property = '.'.join(path_parts)
            
            l10n_strings.append(L10nString(swift_property, localizable_key, i))
    
    return l10n_strings


def get_all_swift_content(repo_root: Path) -> str:
    """
    Get all Swift source code content (excluding generated Strings.swift).
    Uses git ls-files for efficiency.
    """
    try:
        # Get all Swift files tracked by git
        result = subprocess.run(
            ['git', 'ls-files', '*.swift'],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=True
        )
        swift_files = result.stdout.strip().split('\n')
        
        # Exclude the generated Strings.swift and related files
        swift_files = [
            f for f in swift_files 
            if f and 'Swiftgen' not in f and 'SwiftGen' not in f
        ]
        
        # Read all content
        all_content = []
        for swift_file in swift_files:
            file_path = repo_root / swift_file
            if file_path.exists():
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        all_content.append(f.read())
                except Exception:
                    pass  # Skip files that can't be read
        
        return '\n'.join(all_content)
    except Exception as e:
        print(f"Error reading Swift files: {e}", file=sys.stderr)
        return ""


def find_unused_strings(repo_root: Path, strings_swift_path: Path) -> List[L10nString]:
    """
    Find L10n strings that are not used anywhere in the codebase.
    
    Returns a list of unused L10nString objects.
    """
    print("Parsing Strings.swift...")
    l10n_strings = parse_strings_swift(strings_swift_path)
    print(f"Found {len(l10n_strings)} L10n strings")
    
    print("\nReading all Swift source code...")
    all_swift_content = get_all_swift_content(repo_root)
    print(f"Read {len(all_swift_content)} characters of Swift code")
    
    unused_strings = []
    
    print("\nChecking for unused strings...")
    for i, l10n_str in enumerate(l10n_strings):
        if (i + 1) % 100 == 0:
            print(f"Checked {i + 1}/{len(l10n_strings)} strings...")
        
        # Check if L10n property is used
        property_parts = l10n_str.swift_property.split('.')
        leaf_property = property_parts[-1] if property_parts else l10n_str.swift_property
        
        swift_used = False
        
        # Check full L10n path usage (case-insensitive)
        full_path = f"L10n.{l10n_str.swift_property}"
        if full_path.lower() in all_swift_content.lower():
            swift_used = True
        
        # Check leaf property/function usage (more permissive check)
        if not swift_used:
            # For leaf property, we check with common patterns
            if f".{leaf_property}" in all_swift_content:
                swift_used = True
        
        # If not used as L10n property, check if the Localizable key is used directly
        # (e.g., in NSLocalizedString calls or string literals)
        direct_key_used = False
        if not swift_used:
            # Check if the localizable key is referenced directly as a string
            if f'"{l10n_str.localizable_key}"' in all_swift_content:
                direct_key_used = True
        
        if not swift_used and not direct_key_used:
            unused_strings.append(l10n_str)
    
    return unused_strings


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
    unused_strings = find_unused_strings(repo_root, strings_swift_path)
    
    # Report results
    print(f"\n{'='*80}")
    print(f"UNUSED STRINGS REPORT")
    print(f"{'='*80}\n")
    
    if not unused_strings:
        print("✅ No unused strings found!")
        sys.exit(0)
    
    print(f"Found {len(unused_strings)} unused strings:\n")
    
    # Group by prefix for better readability
    grouped: Dict[str, List[L10nString]] = {}
    for unused in unused_strings:
        parts = unused.swift_property.split('.')
        prefix = parts[0] if len(parts) > 1 else "root"
        if prefix not in grouped:
            grouped[prefix] = []
        grouped[prefix].append(unused)
    
    for prefix in sorted(grouped.keys()):
        print(f"\n{prefix.upper()}:")
        for unused in sorted(grouped[prefix], key=lambda x: x.swift_property):
            print(f"  - L10n.{unused.swift_property}")
            print(f"    Key: {unused.localizable_key}")
            print(f"    Line: {unused.line_number}")
    
    print(f"\n{'='*80}")
    print(f"Total unused: {len(unused_strings)}")
    print(f"{'='*80}\n")
    
    # Exit with error code to indicate unused strings were found
    sys.exit(1)


if __name__ == "__main__":
    main()
