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
fails and requests changes on the pull request. When the tracefile is missing, because the
test run or the conversion failed, that job skips the gate instead of blocking on a number
it could not measure.

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

### UpdateSwiftPackages.py

Finds and applies updates for the Swift packages `HomeAssistant.xcodeproj` depends on.
Renovate keeps the gems and GitHub Actions current but has no manager for the package
references in `project.pbxproj` or for `Package.resolved`, so the weekly
`Update Swift Packages` workflow runs this script and opens one pull request per
package that has a newer release.

**Usage:**
```bash
python3 Tools/UpdateSwiftPackages.py                  # list packages with a newer release
python3 Tools/UpdateSwiftPackages.py --apply GRDB.swift  # update one package
python3 Tools/UpdateSwiftPackages.py --apply-all      # update every outdated package
```

**What it does:**
1. Reads every `XCRemoteSwiftPackageReference` in `project.pbxproj` and the pins in the
   workspace `Package.resolved`
2. Asks each repository for its tags with `git ls-remote` and keeps the highest stable
   semantic version; a `branch` requirement compares the branch head with the pinned revision,
   and a `revision` requirement is pinned on purpose and skipped
3. With `--apply`, sets the project's requirement to that version, updates the local packages
   under `Sources/` that pin the same dependency with `exact:` or `from:` so Xcode's package
   graph keeps unifying them, runs `xcodebuild -resolvePackageDependencies`, and regenerates the
   root `Package.resolved` mirror that CI keys its caches on

**Exit codes:**
- `0`: Listed the packages, or applied the requested updates
- `1`: Unknown package name, or the resolved pin does not match the requested version

## Shell Scripts

### BuildMaterialDesignIconsFont.sh

Builds the Material Design Icons font file from the icon definitions.

## Stencil Templates

### icons.stencil

SwiftGen template for generating Swift code from Material Design Icons JSON data.
