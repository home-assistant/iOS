# Unused L10n String Detection and Cleanup

This document describes the automated system for detecting and removing unused localization (L10n) strings in the Home Assistant iOS app.

## Overview

The system consists of:
1. **Detection Script** - Identifies unused L10n strings
2. **Removal Script** - Safely removes unused strings and regenerates code
3. **CI Check** - Automatically detects unused strings in pull requests
4. **Automated Cleanup Workflow** - Creates PRs to clean up unused strings monthly

## Components

### 1. Detection Script (`Tools/detect_unused_strings.py`)

**Purpose**: Identifies L10n strings that are not used anywhere in the codebase.

**How it works**:
1. Parses `Sources/Shared/Resources/Swiftgen/Strings.swift` to extract all L10n properties
2. Reads all Swift source files once for efficient searching
3. Checks for:
   - Full L10n property path usage (e.g., `L10n.About.title`)
   - Leaf property usage (e.g., `.title`)
   - Direct Localizable key usage (e.g., `"about.title"`)
4. Reports unused strings grouped by category

**Usage**:
```bash
python3 Tools/detect_unused_strings.py
```

**Exit Codes**:
- `0`: No unused strings found
- `1`: Unused strings detected (exits with 1 to enable workflow detection)

### 2. Removal Script (`Tools/remove_unused_strings.py`)

**Purpose**: Removes unused strings from all language files and regenerates Strings.swift.

**How it works**:
1. Uses the detection script to find unused strings
2. Removes matching entries from all `*.lproj/Localizable.strings` files
3. Runs SwiftGen to regenerate `Strings.swift`
4. Reports detailed summary of changes

**Prerequisites**:
- Python 3.x
- CocoaPods dependencies installed (`bundle exec pod install`)

**Usage**:
```bash
python3 Tools/remove_unused_strings.py
```

**Safety Features**:
- Only removes strings that are truly unused
- Regenerates code immediately to maintain consistency
- Changes are visible in git for review before commit

### 3. CI Check (`.github/workflows/ci.yml`)

**Purpose**: Alert developers when unused strings are introduced or exist in PRs.

**Job**: `check-unused-strings`
- Runs on every pull request
- Executes the detection script
- Posts a sticky comment on the PR with results
- Non-blocking (informational only)

**Comment Format**:
- Shows count of unused strings
- Includes detailed list in collapsible section
- Suggests using the removal script or automated workflow

### 4. Automated Cleanup Workflow (`.github/workflows/clean_unused_strings.yml`)

**Purpose**: Automatically create PRs to clean up unused strings.

**Triggers**:
- Manual dispatch (workflow_dispatch)
- Monthly schedule (1st of each month at 00:00 UTC)

**Process**:
1. Checks out main branch
2. Runs detection script
3. If unused strings found:
   - Installs dependencies (Ruby, Pods)
   - Runs removal script
   - Creates pull request with changes
4. If no unused strings, exits successfully

**PR Details**:
- Title: "Remove unused L10n strings"
- Labels: `automated`, `localization`, `cleanup`
- Includes detailed summary and list of removed strings

## Implementation Details

### String Detection Algorithm

The detection script uses a multi-step approach:

1. **Parse Strings.swift**: Extracts L10n enum structure using regex patterns
   - Tracks enum nesting using a stack
   - Identifies both properties and functions
   - Maps L10n properties to Localizable keys

2. **Efficient Code Search**: Reads all Swift files once into memory
   - Avoids multiple git grep calls
   - Case-insensitive matching for robustness
   - Checks multiple usage patterns

3. **Multi-Pattern Matching**:
   - Full path: `L10n.About.title`
   - Leaf property: `.title`
   - Direct key: `"about.title"`

### String Removal Process

The removal script:

1. Uses detection script to get unused keys
2. For each unused key:
   - Iterates through all language directories
   - Matches the key using a precise regex pattern
   - Removes the line from the file
3. Regenerates Strings.swift using SwiftGen
4. Reports summary of changes

### Safety Considerations

- **Double-checking**: Both L10n usage and direct key usage are checked
- **Regex precision**: Handles escaped characters and complex string values
- **Git visibility**: All changes are visible for review
- **Reversibility**: Changes can be reverted before merging
- **CI notification**: Developers are informed about unused strings

## Maintenance

### Adding New Checks

To enhance the detection script:
1. Edit `Tools/detect_unused_strings.py`
2. Add new patterns to check in the `find_unused_strings` function
3. Test with: `python3 Tools/detect_unused_strings.py`

### Modifying CI Behavior

To change when checks run:
1. Edit `.github/workflows/ci.yml` (PR checks)
2. Edit `.github/workflows/clean_unused_strings.yml` (automated cleanup)

### Updating Schedule

To change cleanup frequency:
1. Edit `.github/workflows/clean_unused_strings.yml`
2. Modify the `cron` expression under `schedule`

## Troubleshooting

### Detection Script Reports False Positives

- Check if the string is used in a way not covered by patterns
- Consider if the string is used in non-Swift files (storyboards, etc.)
- Verify the L10n property path is correctly parsed

### Removal Script Fails to Regenerate

- Ensure Pods are installed: `bundle exec pod install`
- Check SwiftGen is available: `./Pods/SwiftGen/bin/swiftgen --version`
- Verify swiftgen.yml configuration is correct

### CI Check Not Running

- Verify the workflow file has correct YAML syntax
- Check GitHub Actions permissions
- Ensure Python setup-python action is available

### Automated Workflow Not Creating PR

- Check workflow run logs in GitHub Actions
- Verify `GITHUB_TOKEN` has correct permissions
- Ensure no unused strings were found (workflow skips if nothing to clean)

## Future Enhancements

Potential improvements:
- Support for Core.strings and Frontend.strings
- Integration with localization service (Lokalise)
- Interactive mode for reviewing each string before removal
- Support for detecting unused strings in other file types
- Performance optimizations for very large codebases

## References

- SwiftGen: https://github.com/SwiftGen/SwiftGen
- Lokalise: Used for translation management
- GitHub Actions: https://docs.github.com/en/actions
