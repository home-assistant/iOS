# AI Agent Instructions for Home Assistant iOS

This document provides guidance for AI coding agents (LLMs) working on the Home Assistant for Apple Platforms codebase.

## Project Overview

Home Assistant for Apple Platforms is a native Swift companion app for [Home Assistant](https://www.home-assistant.io/) home automation. The primary user interaction is through a `WKWebView` displaying the Home Assistant web frontend, with native features for notifications, sensors, location tracking, widgets, CarPlay, Apple Watch, and more.

- **Language**: Swift 5.8+
- **Platforms**: iOS, watchOS, macOS (Catalyst), CarPlay
- **Build System**: Xcode 26.2+, CocoaPods, Swift Package Manager
- **Workspace**: Always open `HomeAssistant.xcworkspace` (not the `.xcodeproj`)

## Getting Started

### Install Dependencies

```bash
bundle install
bundle exec pod install --repo-update
```

> CocoaPods and Swift Package Manager (SPM) manage third-party dependencies. CocoaPods is used for most dependencies, while SPM is used for select packages (e.g., swift-snapshot-testing, WebRTC, ZIPFoundation, firebase-ios-sdk).

### Code Signing (for device builds)

Create `Configuration/HomeAssistant.overrides.xcconfig` (git-ignored):

```
DEVELOPMENT_TEAM = YourTeamID
BUNDLE_ID_PREFIX = some.bundle.prefix
```

## Project Structure

```
Sources/
├── App/              # Main iOS app target
├── Shared/           # Shared code across all platforms
├── Watch/            # watchOS-specific code
├── WatchApp/         # watchOS app target
├── MacBridge/        # macOS Catalyst bridge
├── CarPlay/          # CarPlay integration
├── Extensions/       # App Extensions (widgets, notifications, intents)
├── Improv/           # Improv BLE provisioning
├── PushServer/       # Push notification server communication
├── SharedPush/       # Shared push notification handling
├── SharedTesting/    # Shared testing utilities
├── Thread/           # Thread network support
├── Launcher/         # App launcher helper
Tests/
├── App/              # App-level tests
├── Shared/           # Shared module tests
├── UI/               # UI tests
├── Widgets/          # Widget tests
├── Mocks/            # Mock objects for testing
Configuration/        # Xcode build configuration files
fastlane/             # Fastlane automation (build, test, deploy)
Tools/                # Build tools, icon generation
```

## Architecture: The "World" Pattern (Dependency Injection)

This project uses the **"World" pattern** for dependency injection, inspired by [Point-Free's "How to Control the World"](https://www.pointfree.co/blog/posts/21-how-to-control-the-world). This is the most important architectural concept in the codebase.

### How It Works

A single global `Current` variable of type `AppEnvironment` holds all dependencies as mutable properties:

```swift
// Sources/Shared/Environment/Environment.swift
public var Current: AppEnvironment { ... }

public class AppEnvironment {
    public var date: () -> Date = Date.init
    public var calendar: () -> Calendar = { Calendar.autoupdatingCurrent }
    public var servers: ServerManager = ServerManagerImpl()
    public var clientEventStore: ClientEventStoreProtocol = ClientEventStore()
    // ... many more dependencies
}
```

### Usage in Production Code

Access dependencies through `Current`:

```swift
let now = Current.date()
let server = Current.servers.all.first
Current.Log.info("Something happened")
```

### Usage in Tests

Override dependencies for testing:

```swift
Current.date = { Date(timeIntervalSince1970: 1000000) }
Current.servers = FakeServerManager()
```

### ⚠️ Critical Rule

**Never assign to `Current.*` properties outside of test code.** This is enforced by a custom SwiftLint rule that will fail CI. In production code, only _read_ from `Current`.

## Localization

### How Strings Work

1. **Add strings** to the English `.strings` file: `Sources/App/Resources/en.lproj/Localizable.strings`
2. **SwiftGen auto-generates** type-safe accessors in `Sources/Shared/Resources/SwiftGen/Strings.swift` when building the app
3. **Use generated accessors** via the `L10n` enum:

```swift
// In Localizable.strings:
"settings.title" = "Settings";
"sensor.name_%@" = "Sensor: %@";

// In Swift code (auto-generated):
let title = L10n.Settings.title
let name = L10n.Sensor.name("Temperature")
```

There are multiple string tables:
- `Localizable.strings` → `L10n` enum
- `Core.strings` → `CoreStrings` enum
- `Frontend.strings` → `FrontendStrings` enum

All string lookup flows through `Current.localized.string` which handles locale fallback.

> **Important**: Translations for other languages are managed externally via [Lokalise](https://lokalise.com/public/834452985a05254348aee2.46389241/). Only add/modify strings in the `en.lproj` files.

## Code Style & Linting

### Automated Linting

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

## Testing

### Running Tests

```bash
bundle exec fastlane test
```

Or in Xcode: use the `Tests-Unit` scheme with ⌘U.

### Testing Conventions

- Tests live in `Tests/` mirroring the source structure
- Mock dependencies by overriding `Current.*` properties in test setup
- Use `Sources/SharedTesting/` for shared test utilities
- Tests are excluded from SwiftLint enforcement

## Continuous Integration

CI runs on GitHub Actions (`.github/workflows/ci.yml`):

- **Linting**: SwiftFormat, SwiftLint, Rubocop, YamlLint
- **Unit Tests**: Runs the `Tests-Unit` scheme
- **Build Verification**: Ensures the app builds cleanly

All lint checks and tests must pass before a PR can be merged.

## Common Patterns

### Networking

Use `HAKit` (the Home Assistant Swift SDK) for server communication:
- REST API calls via `HAConnection`
- WebSocket subscriptions for real-time updates
- Connection info managed through `Current.servers`

### Data Persistence

- **GRDB**: Primary database for structured data (servers, configurations)
- **Realm**: Legacy data storage (being migrated)
- **UserDefaults**: Simple preferences and watch communication

### UI Patterns

- **SwiftUI**: Preferred for new UI (settings, widgets)
- **UIKit**: Used in older code and where needed for platform APIs
- Use `View.embeddedInHostingController()` for SwiftUI-to-UIKit bridging
- View models are annotated with `@MainActor`
- Support both light and dark mode

### Assets

- SF Symbols via `SFSafeSymbols` library
- Material Design Icons available via `MaterialDesignIcons` (auto-generated from JSON)
- Asset catalogs in `Sources/Shared/Assets/SharedAssets.xcassets`

## Workflow Summary

1. **Install dependencies**: `bundle install && bundle exec pod install --repo-update`
2. **Make your changes** in the appropriate `Sources/` directory
3. **Add strings** to `en.lproj/Localizable.strings` if needed (SwiftGen generates accessors on build)
4. **Run autocorrect**: `bundle exec fastlane autocorrect`
5. **Run tests**: `bundle exec fastlane test`
6. **Commit** your changes

## Additional Resources

- [Home Assistant Developer Docs (Apple)](https://developers.home-assistant.io/docs/apple/)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Point-Free: How to Control the World](https://www.pointfree.co/blog/posts/21-how-to-control-the-world)
