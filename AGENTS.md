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

## The WKWebView Frontend

The primary iOS UI is a `WKWebView` (`WebViewController`) that renders the Home Assistant web frontend; native Swift code wraps it with platform integrations. `WebViewController` functionality is spread across many `WebViewController+*.swift` extension files (navigation, gestures, alerts, URL loading, etc.). Native features communicate with the web UI via a JavaScript message bus handled by `WebViewExternalMessageHandler` (messages typed as `WebViewExternalBusMessage` / `WebViewExternalBusOutgoingMessage` in `Sources/App/Frontend/ExternalMessageBus/`) and custom URL schemes / deep links defined in `AppConstants`.

## MagicItem — Cross-Platform Action Abstraction

`MagicItem` (`Sources/Shared/MagicItem/MagicItem.swift`) is the shared model for items that can appear in Widgets, Watch, CarPlay, and App Shortcuts. It has a `type` (`.script`, `.scene`, `.entity`, `.action`, `.folder`, `.assistPipeline`) and an optional `action` override. `ItemType.rawValue` is persisted (Codable), so **never change existing raw values**.

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

### Snapshot Testing

New SwiftUI views should have snapshot tests using helpers from `SharedTesting`:

```swift
import SharedTesting

func testMyView() {
    assertLightDarkSnapshots(of: MyView()) // tests both light and dark mode
}
```

## Continuous Integration

CI runs on GitHub Actions (`.github/workflows/ci.yml`):

- **Linting**: SwiftFormat, SwiftLint, Rubocop, YamlLint
- **Unit Tests**: Runs the `Tests-Unit` scheme
- **Build Verification**: Ensures the app builds cleanly

All lint checks and tests must pass before a PR can be merged.

## Common Patterns

### Concurrency

**Prefer Swift Concurrency (`async`/`await`, `Task`, actors, structured concurrency) for all new asynchronous code.**

- **Do not introduce new [PromiseKit](https://github.com/mxcl/PromiseKit) code.** PromiseKit is a legacy dependency that the codebase is gradually moving away from. Parts of `HomeAssistantAPI` (`HAAPI.swift`) still use it, so don't assume a full migration — but new work should use `async`/`await` instead of `Promise`/`Guarantee`.
- When touching existing PromiseKit code, migrate it to `async`/`await` where practical rather than extending the PromiseKit usage.
- Use `Combine` only where an existing reactive pattern already requires it; otherwise prefer `async`/`await` and `AsyncStream`/`AsyncSequence`.
- Annotate SwiftUI-facing view models with `@MainActor`.

### Live Activities & Push Notifications

**When implementing or fixing anything related to Live Activities (or push notifications generally), always check BOTH delivery flows — local push and remote push.** They are handled by different code paths, so a field, behavior, or fix applied to one is easily missed in the other (e.g. a payload key parsed for APNs but dropped over local push, or alerting/sound handled differently per flow).

- **Remote push (APNs / cloud)**: Home Assistant → the push relay (`Sources/PushServer`) → APNs → the app / `Sources/Extensions/NotificationService`. The payload already carries a `homeassistant` dictionary.
- **Local push (WebSocket / `NEAppPushProvider`)**: delivered over the on-network channel and handled by `Sources/Extensions/PushProvider` + `Sources/Shared/Notifications/LocalPush` (`LocalPushManager`, `LocalPushEvent`). The payload arrives as a flat `{message, data}` shape and is reshaped by `LegacyNotificationParserImpl` (`Sources/SharedPush/Sources/NotificationParserLegacy.swift`), which must explicitly **promote** `data` fields into `homeassistant` — any field not in that promotion list is silently dropped on this flow only.

Both flows converge on `NotificationCommandManager` → `HandlerStartOrUpdateLiveActivity` → `LiveActivityRegistry` (`Sources/Shared/LiveActivity`), with the UI rendered by `Sources/Extensions/Widgets/LiveActivity`.

Practical checklist when changing this area:
- If you add or read a notification/Live-Activity payload field, confirm it survives **both** the local-push parser promotion list and the remote-push payload.
- Verify alerting behavior (sound, haptics, banner suppression, the `silent` flag) on **both** flows — local push presents notifications through `LocalPushManager`, not the system directly.
- `Sources/SharedPush` is vendored as a separate copy under `Sources/PushServer/SharedPush` (the relay). Keep the two parser copies in sync when a parsing change is relevant to **both** the app and the relay; some logic intentionally lives in only one copy (e.g. the Live Activity `live_update` promotion is app-only, since the relay/cloud path already carries a `homeassistant` dict). When you change one copy, decide explicitly whether the other needs the same change.
- Add/extend tests for both flows (e.g. `Tests/Shared/LocalPushManager.test.swift` for the local path, `Sources/PushServer/Tests/SharedPushTests` for the relay/parser).

### Networking

Use `HAKit` (the Home Assistant Swift SDK) for server communication:
- REST API calls via `HAConnection`
- WebSocket subscriptions for real-time updates
- Connection info managed through `Current.servers`
- Prefer `async`/`await` for new request flows (see [Concurrency](#concurrency)); avoid adding new PromiseKit-based calls.

### Data Persistence

The project uses **two** database layers:

- **GRDB** (`GRDB.swift`): newer layer, accessed via `Current.database()`. Used for Watch config, CarPlay config, widget config, entity registry, panels, etc. When adding a new persistent model, prefer GRDB: implement `DatabaseTableProtocol` (defines `tableName`, `definedColumns`, and `createIfNeeded`) and register it in `DatabaseQueue.tables()` in `GRDB+Initialization.swift`. The protocol's `migrateColumns` helper auto-handles additive migrations.
- **Realm** (`RealmSwift`): legacy layer, used for older models (actions, zones, sensors, etc.). Access via `Current.realm()`.
- **UserDefaults**: simple preferences and watch communication.

### Logging

Use `Current.Log` (XCGLogger) — never `print` or `NSLog`:

```swift
Current.Log.info("Connected to \(server.info.name)")
Current.Log.error("Failed: \(error.localizedDescription)")
Current.Log.verbose("Debug detail")
```

### `with()` Helper

`with(_:update:)` in `Sources/Shared/Common/With.swift` is used for fluent inline initialization:

```swift
public lazy var webhooks = with(WebhookManager()) {
    $0.register(responseHandler: ..., for: .updateSensors)
}
```

### UI Patterns

- **SwiftUI**: Preferred for new UI (settings, widgets)
- **UIKit**: Used in older code and where needed for platform APIs
- Use `View.embeddedInHostingController()` for SwiftUI-to-UIKit bridging
- View models are annotated with `@MainActor`
- Support both light and dark mode

#### SwiftUI View Conventions

- **One struct per file**: whenever a new `View` struct is introduced, put it in its own file. Do not stack multiple view structs in one file.
- **Keep everything in `body`**: build the view's content inline inside `body`. Do not abstract portions out into separate reusable subviews (helper view structs or computed `some View` properties) just to break `body` up. Extract a new struct only when it is genuinely reused elsewhere, and when you do, it gets its own file (see above).
- **Always add a `#Preview`**: every SwiftUI view must ship with a preview so it can be checked quickly in Xcode.
- **Snapshot tests for new features**: any new feature that adds UI must include snapshot tests (see [Snapshot Testing](#snapshot-testing)).

### Assets

- SF Symbols via `SFSafeSymbols` library (`Image(systemSymbol: .house)`), never the string-based API
- HA domain/entity icons via the `MaterialDesignIcons` enum (auto-generated from JSON); names carry an `Icon` suffix (e.g. `.lightbulbIcon`), and `Domain.icon(deviceClass:state:)` provides domain-appropriate icons
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
