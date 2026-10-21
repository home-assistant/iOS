---
name: ha-ios-code-style
description: Swift code style, linting, logging, assets, and idioms for Home Assistant iOS. Use when writing or formatting Swift, declaring an enum that is Codable, Decodable, Encodable, or decoded from HAData, running SwiftFormat/SwiftLint, referencing SF Symbols or Material Design icons, logging, or using the with() helper.
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

## Serialized Enums Need an `unknown` Case

Every `enum` that is `Codable`, `Decodable`, or `Encodable`, or that is read out of `HAData` (a `HADataDecodable` model, or a field decoded from one), declares a case named `unknown` and decodes any unmapped value into it. Home Assistant core, the frontend, and newer app builds (via iCloud restore, the Watch mirror, or configuration transfer) add values this build has never seen, and one unmapped string must never fail the whole payload. This applies to new enums and to any existing enum you make serializable.

`RawRepresentable` enums get a synthesized `init(from:)` that throws on an unknown raw value, so override it:

```swift
// ✅ Correct: unmapped values land in `.unknown`
public enum AssistEvent: String, Codable {
    case runStart = "run-start"
    case runEnd = "run-end"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AssistEvent(rawValue: rawValue) ?? .unknown
    }
}

// ❌ Wrong: relies on the synthesized initializer, so a new server value throws
public enum AssistEvent: String, Codable {
    case runStart = "run-start"
    case runEnd = "run-end"
}
```

For a `HADataDecodable` model, map the field the same way rather than letting the decode throw:

```swift
public init(data: HAData) throws {
    self.status = Status(rawValue: try data.decode("status")) ?? .unknown
}
```

- Name the case exactly `unknown`, so the fallback reads the same everywhere.
- Handle `.unknown` deliberately in every `switch` (hide the row, show a placeholder, skip the action). Do not reach it through a `default:` that silently treats it as something else.
- Keep encoding honest: `.unknown` has a raw value of `"unknown"`, so do not send it back to the server as if it were a real value. Where a model round-trips, keep the original string alongside the enum or skip the field on encode.
- `AppEnum` types used by App Intents follow the same rule when they are also persisted or decoded from the server.

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
