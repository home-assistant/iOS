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

### diff_coverage.py

Measures how much of a pull request's own diff the unit tests cover, out of the LCOV
tracefile `xccov_to_lcov.py` writes. CI's `patch-coverage` job gates on it: below 90%, it
fails and requests changes on the pull request.

**Usage:**
```bash
python3 Tools/diff_coverage.py fastlane/test_output/coverage.lcov --base origin/main
```

**What it does:**
1. Reads the LCOV tracefile as per-line execution counts
2. Takes the lines the branch adds or changes from `git diff --unified=0 <base>...HEAD`
3. Keeps the changed lines that coverage marks executable, dropping ignored paths
4. Reports the covered share, a per-file table, and which changed lines no test runs

**Exit codes:**
- `0`: Coverage of the changed lines is at or above `--threshold` (default 90%)
- `1`: Coverage is below the threshold, or the tracefile is missing

## Shell Scripts

### BuildMaterialDesignIconsFont.sh

Builds the Material Design Icons font file from the icon definitions.

## Stencil Templates

### icons.stencil

SwiftGen template for generating Swift code from Material Design Icons JSON data.
