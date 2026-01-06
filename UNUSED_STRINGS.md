# Unused L10n String Detection

This document describes the automated system for detecting unused localization (L10n) strings in the Home Assistant iOS app.

## Overview

The system consists of:
1. **Detection Script** - Identifies unused L10n strings
2. **CI Check** - Automatically detects unused strings in pull requests

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

### 2. CI Check (`.github/workflows/ci.yml`)

**Purpose**: Alert developers when unused strings are introduced or exist in PRs.

**Job**: `check-unused-strings`
- Runs on every pull request
- Executes the detection script
- Posts a sticky comment on the PR with results
- Non-blocking (informational only)

**Comment Format**:
- Shows count of unused strings
- Includes detailed list in collapsible section

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

## Troubleshooting

### Detection Script Reports False Positives

- Check if the string is used in a way not covered by patterns
- Consider if the string is used in non-Swift files (storyboards, etc.)
- Verify the L10n property path is correctly parsed

### CI Check Not Running

- Verify the workflow file has correct YAML syntax
- Check GitHub Actions permissions
- Ensure Python setup-python action is available

## Future Enhancements

Potential improvements:
- Automated removal of unused strings
- Support for Core.strings and Frontend.strings
- Integration with localization service (Lokalise)
- Support for detecting unused strings in other file types
- Performance optimizations for very large codebases

## References

- SwiftGen: https://github.com/SwiftGen/SwiftGen
- Lokalise: Used for translation management
- GitHub Actions: https://docs.github.com/en/actions
