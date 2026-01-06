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

## Shell Scripts

### BuildMaterialDesignIconsFont.sh

Builds the Material Design Icons font file from the icon definitions.

## Stencil Templates

### icons.stencil

SwiftGen template for generating Swift code from Material Design Icons JSON data.
