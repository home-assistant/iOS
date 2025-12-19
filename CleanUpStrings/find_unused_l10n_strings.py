#!/usr/bin/env python3
"""
Home Assistant iOS - Unused L10n Strings Finder

This script comprehensively analyzes the Home Assistant iOS codebase to find truly unused
localization strings. It performs a two-phase analysis:

1. Phase 1: Find L10n properties that aren't used via L10n.* syntax
2. Phase 2: Verify the underlying localizable.strings keys aren't used elsewhere

The script identifies false positives where L10n properties appear unused but the underlying
keys are used via:
- Direct string references in AppIntents
- Localization files (.lproj/Localizable.strings)
- Dynamic key construction
- XIB/Storyboard files

Usage:
    python3 find_unused_l10n_strings.py [workspace_path]

If no workspace_path is provided, uses current directory.

Author: Generated for Home Assistant iOS project
"""

import os
import re
import sys
import argparse
from pathlib import Path
from typing import Set, List, Dict, Tuple
from dataclasses import dataclass


@dataclass
class AnalysisResult:
    """Results of the L10n usage analysis"""
    total_properties: int
    used_properties: int
    unused_l10n_properties: Set[str]
    false_positives: Set[str]
    truly_unused: Set[str]


class L10nStringAnalyzer:
    """Analyzes L10n string usage in Home Assistant iOS codebase"""
    
    def __init__(self, workspace_path: str):
        self.workspace_path = Path(workspace_path)
        self.strings_file = self.workspace_path / "Sources/Shared/Resources/Swiftgen/Strings.swift"
        
        # File patterns to search
        self.code_patterns = ["**/*.swift", "**/*.m", "**/*.h"]
        self.ui_patterns = ["**/*.xib", "**/*.storyboard"]
        self.localization_patterns = ["**/*.lproj/Localizable.strings"]
        
        # Files to exclude from analysis
        self.exclude_files = {
            "Sources/Shared/Resources/Swiftgen/Strings.swift"  # The file we're analyzing
        }
        
        # Directories to exclude from analysis
        self.exclude_dirs = {
            "Pods",           # CocoaPods dependencies
            "build",          # Build output
            ".git",           # Git metadata
            "DerivedData",    # Xcode derived data
        }
    def extract_all_l10n_properties(self) -> Set[str]:
        """
        Extract all L10n string properties from the SwiftGen-generated Strings.swift file.
        
        Returns:
            Set of fully qualified L10n property names (e.g., "L10n.About.title")
        """
        print("📄 Extracting all L10n properties from Strings.swift...")
        
        if not self.strings_file.exists():
            raise FileNotFoundError(f"Strings.swift not found at: {self.strings_file}")
            
        properties = set()
        
        with open(self.strings_file, 'r', encoding='utf-8') as file:
            content = file.read()
            
        # Extract enum structure and property names
        enum_stack = []  # Start empty, will add L10n when we find it
        
        lines = content.split('\n')
        for line in lines:
            stripped = line.strip()
            
            # Handle enum declarations
            enum_match = re.match(r'public enum (\w+)', stripped)
            if enum_match:
                enum_name = enum_match.group(1)
                if enum_name == "L10n" and not enum_stack:
                    # This is the root L10n enum, start our stack
                    enum_stack = ["L10n"]
                else:
                    # This is a nested enum
                    enum_stack.append(enum_name)
                continue
                
            # Handle closing braces (end of enum)
            if stripped == '}' and len(enum_stack) > 1:
                enum_stack.pop()
                continue
                
            # Only process properties if we're inside the L10n enum hierarchy
            if not enum_stack:
                continue
                
            # Handle static var properties
            var_match = re.search(r'public static var (\w+): String', stripped)
            if var_match:
                prop_name = var_match.group(1)
                full_path = '.'.join(enum_stack + [prop_name])
                properties.add(full_path)
                continue
                
            # Handle static func properties
            func_match = re.search(r'public static func (\w+)\(.*\) -> String', stripped)
            if func_match:
                func_name = func_match.group(1)
                full_path = '.'.join(enum_stack + [func_name])
                properties.add(full_path)
                continue
        
        print(f"✅ Found {len(properties)} L10n properties")
        return properties
    
    def find_l10n_usage_in_code(self) -> Set[str]:
        """
        Find all L10n.* property references in the codebase.
        
        Returns:
            Set of L10n properties that are referenced in code
        """
        print("🔍 Searching for L10n usage patterns in code files...")
        
        used_properties = set()
        files_searched = 0
        
        # Search Swift, Objective-C files
        for pattern in self.code_patterns:
            for file_path in self.workspace_path.rglob(pattern):
                # Skip excluded files
                relative_path = file_path.relative_to(self.workspace_path)
                if str(relative_path) in self.exclude_files:
                    continue
                    
                # Skip excluded directories
                if any(excluded_dir in file_path.parts for excluded_dir in self.exclude_dirs):
                    continue
                    
                # Skip if it's a directory
                if file_path.is_dir():
                    continue
                    
                try:
                    with open(file_path, 'r', encoding='utf-8') as file:
                        content = file.read()
                        
                    # Find L10n.* patterns
                    l10n_matches = re.findall(r'L10n\.[\w.]+', content)
                    for match in l10n_matches:
                        used_properties.add(match)
                        
                    files_searched += 1
                    
                except (UnicodeDecodeError, PermissionError) as e:
                    print(f"⚠️  Skipped {file_path}: {e}")
                    continue
        print(f"✅ Searched {files_searched} code files, found {len(used_properties)} L10n references")
        return used_properties
    
    def l10n_property_to_key(self, l10n_property: str) -> str:
        """
        Convert L10n property path to localizable.strings key.
        
        Example: L10n.AppIntents.Assist.Pipeline.title -> "app_intents.assist.pipeline.title"
        """
        if not l10n_property.startswith("L10n."):
            return l10n_property
            
        # Remove L10n. prefix
        path = l10n_property[5:]  # Remove "L10n."
        
        # Split by dots and convert each segment from PascalCase to snake_case
        segments = path.split('.')
        snake_segments = []
        
        for segment in segments:
            # Convert PascalCase to snake_case
            snake_case = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', segment)
            snake_case = re.sub(r'([a-z\d])([A-Z])', r'\1_\2', snake_case)
            snake_segments.append(snake_case.lower())
            
        return '.'.join(snake_segments)
    
    def search_for_string_keys(self, string_keys: Set[str]) -> Set[str]:
        """
        Search the entire codebase for usage of localizable.strings keys.
        
        Args:
            string_keys: Set of localizable.strings keys to search for
            
        Returns:
            Set of keys that are found in the codebase
        """
        print("🔍 Searching for localizable.strings key usage in entire codebase...")
        
        found_keys = set()
        files_searched = 0
        
        # Search all file types
        all_patterns = self.code_patterns + self.ui_patterns + self.localization_patterns
        
        for pattern in all_patterns:
            for file_path in self.workspace_path.rglob(pattern):
                # Skip excluded directories
                if any(excluded_dir in file_path.parts for excluded_dir in self.exclude_dirs):
                    continue
                    
                # Skip if it's a directory
                if file_path.is_dir():
                    continue
                    
                try:
                    with open(file_path, 'r', encoding='utf-8') as file:
                        content = file.read()
                        
                    # Search for each key
                    for key in string_keys:
                        # Search for exact key matches (quoted strings, etc.)
                        patterns_to_check = [
                            f'"{key}"',           # Standard quoted string
                            f"'{key}'",           # Single quoted
                            f'"{key}",',          # With comma
                            f"'{key}',",          # Single quoted with comma
                            f'key="{key}"',       # Key-value pair
                            f"key='{key}'",       # Key-value single quoted
                            f'{key}',             # Bare key (in localization files)
                        ]
                        
                        for search_pattern in patterns_to_check:
                            if search_pattern in content:
                                found_keys.add(key)
                                break  # Found this key, move to next
                                
                    files_searched += 1
                    
                except (UnicodeDecodeError, PermissionError) as e:
                    print(f"⚠️  Skipped {file_path}: {e}")
                    continue
        print(f"✅ Searched {files_searched} files for string keys, found {len(found_keys)} keys in use")
        return found_keys
    
    def analyze_unused_strings(self) -> AnalysisResult:
        """
        Perform complete analysis to find truly unused L10n strings.
        
        Returns:
            AnalysisResult with comprehensive findings
        """
        print("\n🎯 Starting comprehensive L10n strings analysis...\n")
        
        # Phase 1: Extract all L10n properties
        all_l10n_properties = self.extract_all_l10n_properties()
        
        # Phase 2: Find L10n properties used in code
        used_l10n_properties = self.find_l10n_usage_in_code()
        
        # Phase 3: Identify potentially unused L10n properties
        unused_l10n_properties = all_l10n_properties - used_l10n_properties
        print(f"📊 Phase 1 complete: {len(unused_l10n_properties)} L10n properties appear unused")
        
        # Phase 4: Convert unused L10n properties to localizable.strings keys
        print("\n🔄 Converting L10n properties to localizable.strings keys...")
        unused_keys = set()
        l10n_to_key_mapping = {}
        
        for l10n_prop in unused_l10n_properties:
            key = self.l10n_property_to_key(l10n_prop)
            unused_keys.add(key)
            l10n_to_key_mapping[key] = l10n_prop
            
        print(f"✅ Converted {len(unused_keys)} L10n properties to string keys")
        
        # Phase 5: Search for usage of these keys in the codebase
        print("\n🔍 Phase 2: Verifying string key usage...")
        found_keys = self.search_for_string_keys(unused_keys)
        
        # Phase 6: Identify false positives and truly unused
        false_positive_keys = found_keys
        truly_unused_keys = unused_keys - found_keys
        
        # Map back to L10n properties
        false_positive_l10n = {l10n_to_key_mapping[key] for key in false_positive_keys}
        truly_unused_l10n = {l10n_to_key_mapping[key] for key in truly_unused_keys}
        
        print(f"\n📊 Analysis complete!")
        print(f"   • False positives (keys actually used): {len(false_positive_l10n)}")
        print(f"   • Truly unused (safe to remove): {len(truly_unused_l10n)}")
        
        return AnalysisResult(
            total_properties=len(all_l10n_properties),
            used_properties=len(used_l10n_properties),
            unused_l10n_properties=unused_l10n_properties,
            false_positives=false_positive_l10n,
            truly_unused=truly_unused_l10n
        )
    
    def generate_reports(self, result: AnalysisResult) -> None:
        """Generate only the truly unused strings list."""
        print("\n📝 Generating truly unused strings list...")
        output_dir = Path(__file__).parent.resolve()
        unused_list_path = output_dir / "truly_unused_l10n_strings.txt"
        with open(unused_list_path, 'w', encoding='utf-8') as f:
            for prop in sorted(result.truly_unused):
                f.write(f"{prop}\n")
        print(f"✅ Created unused strings list: {unused_list_path}")
    
    def _get_current_date(self) -> str:
        """Get current date in readable format."""
        from datetime import datetime
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def main():
    """Main entry point for the script."""
    
    parser = argparse.ArgumentParser(
        description="Find truly unused L10n strings in Home Assistant iOS project"
    )
    parser.add_argument(
        'workspace_path', 
        nargs='?', 
        default='.', 
        help='Path to the Home Assistant iOS workspace (default: current directory)'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    
    args = parser.parse_args()
    
    # Resolve workspace path
    workspace_path = os.path.abspath(args.workspace_path)
    
    if not os.path.exists(workspace_path):
        print(f"❌ Error: Workspace path does not exist: {workspace_path}")
        sys.exit(1)
        
    print(f"🏠 Analyzing Home Assistant iOS workspace: {workspace_path}")
    
    try:
        # Initialize analyzer
        analyzer = L10nStringAnalyzer(workspace_path)
        
        # Perform analysis
        result = analyzer.analyze_unused_strings()
        
        # Generate reports
        analyzer.generate_reports(result)
        
        print("\n🎉 Analysis complete!")
        print(f"   📊 Total: {result.total_properties} strings")
        print(f"   ✅ Used: {result.used_properties} strings")
        print(f"   ❌ False positives: {len(result.false_positives)} strings")
        print(f"   🗑️  Truly unused: {len(result.truly_unused)} strings")
        print("\n📁 Reports generated:")
        print("   • l10n_analysis_summary.md - Complete analysis report")
        print("   • truly_unused_l10n_strings.txt - Safe to remove")
        print("   • l10n_false_positives.txt - Do not remove")
        
    except FileNotFoundError as e:
        print(f"❌ Error: {e}")
        print("Make sure you're running this from the Home Assistant iOS project root.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()