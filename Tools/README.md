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

### xccov_to_lcov.py

Converts Xcode code coverage from an `.xcresult` bundle into an LCOV tracefile, which is
what Codecov consumes. CI runs it after `fastlane test` so pull requests get a coverage
report; the uploader's own Swift plugin cannot read Xcode result bundles reliably.

**Usage:**
```bash
python3 Tools/xccov_to_lcov.py fastlane/test_output/Tests-Unit.xcresult --lcov coverage.lcov
```

**What it does:**
1. Dumps per-line execution counts with `xcrun xccov view --archive --json`
2. Rewrites absolute source paths as repository-relative paths, dropping anything outside the repository
3. Writes an LCOV tracefile, and optionally appends a Markdown coverage summary to `--summary`

**Exit codes:**
- `0`: Coverage written
- `1`: `xccov` failed, or the bundle covered no repository sources

## Shell Scripts

### BuildMaterialDesignIconsFont.sh

Builds the Material Design Icons font file from the icon definitions.

## Stencil Templates

### icons.stencil

SwiftGen template for generating Swift code from Material Design Icons JSON data.
