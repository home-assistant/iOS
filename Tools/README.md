# Tools Directory

This directory contains scripts and tools used for development and maintenance of the Home Assistant iOS app.

## Python Scripts

### detect_unused_strings.py

Detects unused localization strings in the codebase.

**Usage:**
```bash
python3 Tools/detect_unused_strings.py
```

**What it does:**
1. Parses `Sources/Shared/Resources/Swiftgen/Strings.swift` to extract all L10n properties and their corresponding Localizable keys
2. Checks for usage of L10n properties in Swift source code
3. Double-checks for direct usage of Localizable keys in the codebase
4. Reports unused strings that can be safely removed

**Exit codes:**
- `0`: No unused strings found
- `1`: Unused strings detected (normal for reporting)

### remove_unused_strings.py

Removes unused localization strings from all language files and regenerates Strings.swift.

**Usage:**
```bash
python3 Tools/remove_unused_strings.py
```

**What it does:**
1. Uses `detect_unused_strings.py` to find unused strings
2. Removes them from all `*.lproj/Localizable.strings` files
3. Regenerates `Strings.swift` using SwiftGen

**Requirements:**
- Python 3.x
- SwiftGen (installed via CocoaPods)
- Pods must be installed before running (`bundle exec pod install`)

**Exit codes:**
- `0`: Successfully removed unused strings and regenerated Strings.swift
- `1`: Error occurred during processing

## Shell Scripts

### BuildMaterialDesignIconsFont.sh

Builds the Material Design Icons font file from the icon definitions.

## Stencil Templates

### icons.stencil

SwiftGen template for generating Swift code from Material Design Icons JSON data.
