---
name: ha-ios-code-style
description: Swift code style, linting, logging, assets, and idioms for Home Assistant iOS. Use when writing or formatting Swift, running SwiftFormat/SwiftLint, referencing SF Symbols or Material Design icons, logging, or using the with() helper.
---

# Code Style, Linting, Logging & Assets

## Automated Linting

```bash
# Check for lint issues (does not modify files)
bundle exec fastlane lint

# Auto-fix lint issues (run before committing!)
bundle exec fastlane autocorrect
```

**Always run `bundle exec fastlane autocorrect` after making changes and before committing.**

### Linters Used

| Tool | Config File | Purpose |
|------|-------------|---------|
| SwiftFormat | `.swiftformat` | Code formatting (120 char max, `before-first` wrapping) |
| SwiftLint | `.swiftlint.yml` | Code quality rules |
| Rubocop | `.rubocop.yml` | Ruby/Fastlane code |
| YamlLint | `.yamllint.yml` | YAML files |

### Key SwiftFormat Rules

- Max line width: 120 characters
- Wrap arguments/parameters/collections: `before-first`
- `self` keyword: only in initializers (`--self init-only`)
- Guard else: same line
- Headers: stripped (no file header comments)

### Key SwiftLint Rules

- No `force_cast` or `force_try`
- Keep cyclomatic complexity low
- No assigning to `Current.*` outside tests
- Use `SFSafeSymbols` for SF Symbol references:

```swift
// ❌ Wrong
Image(systemName: "house")

// ✅ Correct
Image(systemSymbol: .house)
```

## Logging

Use `Current.Log` (XCGLogger) — never `print` or `NSLog`:

```swift
Current.Log.info("Connected to \(server.info.name)")
Current.Log.error("Failed: \(error.localizedDescription)")
Current.Log.verbose("Debug detail")
```

## `with()` Helper

`with(_:update:)` in `Sources/Shared/Common/With.swift` is used for fluent inline initialization:

```swift
public lazy var webhooks = with(WebhookManager()) {
    $0.register(responseHandler: ..., for: .updateSensors)
}
```

## Assets

- SF Symbols via `SFSafeSymbols` library (`Image(systemSymbol: .house)`), never the string-based API
- HA domain/entity icons via the `MaterialDesignIcons` enum (auto-generated from JSON); names carry an `Icon` suffix (e.g. `.lightbulbIcon`), and `Domain.icon(deviceClass:state:)` provides domain-appropriate icons
- Asset catalogs in `Sources/Shared/Assets/SharedAssets.xcassets`
