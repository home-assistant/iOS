# GitHub Copilot Instructions for Home Assistant iOS

See [AGENTS.md](../AGENTS.md) for the full AI agent reference. This file provides GitHub Copilot-specific guidance.

Home Assistant for Apple Platforms is a native iOS, watchOS, and macOS companion app for Home Assistant home automation. The primary iOS UI is a **WKWebView** (`WebViewController`) that renders the Home Assistant web frontend; native Swift code wraps it with platform integrations (widgets, CarPlay, Watch, notifications, sensors, etc.).

## Build, Lint, and Test Commands

```bash
# Initial setup
bundle install
bundle exec pod install --repo-update

# Fix lint issues (run before committing)
bundle exec fastlane autocorrect

# Check lint without fixing
bundle exec fastlane lint

# Run unit tests
bundle exec fastlane test
```

Always open `HomeAssistant.xcworkspace` (not the `.xcodeproj`). Run individual tests in Xcode via the Test navigator (⌘U) or by clicking the diamond next to a test method. The unit test scheme is `Tests-Unit`.

### Code Signing

Debug builds use Automatic provisioning. Create `Configuration/HomeAssistant.overrides.xcconfig` (gitignored):

```
DEVELOPMENT_TEAM = YourTeamID
BUNDLE_ID_PREFIX = some.bundle.prefix
```

## Architecture

### Source Layout

| Path | Purpose |
|------|---------|
| `Sources/App` | iOS app — AppDelegate, Scenes, WebViewController, Settings, Onboarding |
| `Sources/Shared` | Cross-platform logic shared by iOS, watchOS, macOS, and extensions |
| `Sources/Watch` / `WatchApp` | watchOS app |
| `Sources/MacBridge` | macOS Catalyst bridge |
| `Sources/CarPlay` | CarPlay integration |
| `Sources/Extensions` | App extensions: Widgets, Notification Service/Content, Push Provider, Intents |
| `Sources/SharedTesting` | Test helpers (snapshot helpers, mock support) |
| `Tests/` | Unit and snapshot tests (mirror source structure) |

### WKWebView Frontend

`WebViewController` is the core UI — it loads the Home Assistant web app. Functionality is spread across many `WebViewController+*.swift` extension files (navigation, gestures, alerts, URL loading, etc.). Native features communicate with the web UI via a JavaScript message bus handled by `WebViewExternalMessageHandler` (messages typed as `WebViewExternalBusMessage` / `WebViewExternalBusOutgoingMessage` in `Sources/App/Frontend/ExternalMessageBus/`) and custom URL schemes / deep links defined in `AppConstants`.

### `Current` Environment (Dependency Injection)

This project uses the "World" pattern. The global `Current: AppEnvironment` object is the DI container. All shared services are accessed through it:

```swift
Current.Log.info("message")
Current.api(for: server)?.CallService(...)
Current.database()
Current.servers.all
```

- **Never assign to `Current` outside of test code** — enforced by a SwiftLint custom rule.
- In tests, replace `Current` with a preconfigured `AppEnvironment` to mock dependencies.
- SwiftUI-facing view models are annotated `@MainActor`.

### Dual Persistence: Realm + GRDB

The project uses **two** database layers:

- **Realm** (`RealmSwift`) — legacy layer, used for older models (actions, zones, sensors, etc.). Access via `Current.realm()`.
- **GRDB** (`GRDB.swift`) — newer layer, accessed via `Current.database()`. Used for Watch config, CarPlay config, widget config, entity registry, panels, etc.

When adding a new persistent model, prefer GRDB. Implement `DatabaseTableProtocol` (defines `tableName`, `definedColumns`, and `createIfNeeded`) and register it in `DatabaseQueue.tables()` in `GRDB+Initialization.swift`. The protocol's `migrateColumns` helper auto-handles additive migrations.

### HAKit (WebSocket + REST)

`HAKit` is the library for all Home Assistant server communication. Use `HATypedRequest` for typed WebSocket/REST calls. Network requests in `HomeAssistantAPI` (`HAAPI.swift`) still use **PromiseKit** for some flows alongside newer `async/await`. Don't assume the codebase is fully migrated to async/await.

### MagicItem — Cross-Platform Action Abstraction

`MagicItem` (`Sources/Shared/MagicItem/MagicItem.swift`) is the shared model for items that can appear in Widgets, Watch, CarPlay, and App Shortcuts. It has a `type` (`.script`, `.scene`, `.entity`, `.action`, `.folder`, `.assistPipeline`) and an optional `action` override. `ItemType.rawValue` is persisted (Codable), so **never change existing raw values**.

## Swift Conventions

- Use Swift's modern language features (async/await, Combine where appropriate). Note: parts of `HomeAssistantAPI` still use **PromiseKit** — don't assume a full async/await migration.
- SwiftUI preferred for new UI; UIKit where existing patterns require it.
- Prefer value types (structs) over reference types (classes) when appropriate.
- Use proper access control (`private`, `fileprivate`, `internal`, `public`).
- Avoid force unwrapping (`!`) and force casting unless absolutely necessary.
- Use guard statements for early returns.
- Keep cyclomatic complexity low — extract helper methods for complex logic.
- SwiftUI-facing view models are annotated `@MainActor` at the type level.

## Key Conventions

### Localized Strings

All user-visible strings come from SwiftGen-generated enums — never use hardcoded string literals. Add new strings to `Sources/App/Resources/en.lproj/Localizable.strings`; the type-safe accessors are regenerated automatically as an Xcode build phase (SwiftGen runs via CocoaPods at `Pods/SwiftGen/bin/swiftgen`).

- `L10n.*` — app-specific strings from `Localizable.strings`
- `CoreStrings.*` — Home Assistant core translations
- `FrontendStrings.*` — Home Assistant frontend translations

### SFSymbols

Use `SFSafeSymbols` for type-safe SF Symbol references:

```swift
// ❌ Avoid
Image(systemName: "house")

// ✅ Prefer
Image(systemSymbol: .house)
```

### Logging

Use `Current.Log` (XCGLogger) — never `print` or `NSLog`:

```swift
Current.Log.info("Connected to \(server.info.name)")
Current.Log.error("Failed: \(error.localizedDescription)")
Current.Log.verbose("Debug detail")
```

### Icons

Use `MaterialDesignIcons` enum for all HA domain/entity icons. Icons are named with the `Icon` suffix (e.g., `.lightbulbIcon`, `.scriptTextOutlineIcon`). The `Domain.icon(deviceClass:state:)` method provides domain-appropriate icons.

### `with()` Helper

`with(_:update:)` in `Sources/Shared/Common/With.swift` is used for fluent inline initialization:

```swift
public lazy var webhooks = with(WebhookManager()) {
    $0.register(responseHandler: ..., for: .updateSensors)
}
```

### SwiftUI ↔ UIKit Bridge

Use `View.embeddedInHostingController()` (defined in `Sources/Shared/Common/Extensions/View+HA.swift`) to wrap SwiftUI views for UIKit presentation — it injects `ViewControllerProvider`.

### Snapshot Testing

New SwiftUI views should have snapshot tests using helpers from `SharedTesting`:

```swift
import SharedTesting

func testMyView() {
    assertLightDarkSnapshots(of: MyView()) // tests both light and dark mode
}
```

Tests in `Tests/` mirror the source structure.

### Dependencies

Dependencies are managed via **both CocoaPods** (most deps, `Podfile`) and **Swift Package Manager** (e.g., `swift-snapshot-testing`, `WebRTC`, `ZIPFoundation`, `firebase-ios-sdk`). Add new dependencies sparingly.

## Linters Configuration

- **SwiftFormat** (`.swiftformat`): 120-char line width, `before-first` argument wrapping, `self` only in initializers, guard-else on same line.
- **SwiftLint** (`.swiftlint.yml`): enabled rules include `cyclomatic_complexity`, `force_cast`, `force_try`, `unused_optional_binding`, `weak_delegate`; custom rules enforce no `Current` assignment outside tests and require `SFSafeSymbols`.
- **Rubocop** (`.rubocop.yml`): for Fastlane/Ruby files.
- **YamlLint** (`.yamllint.yml`): for YAML files.

## Continuous Integration

CI runs on GitHub Actions:
- Linting (SwiftFormat, SwiftLint, Rubocop, YamlLint)
- Unit tests (scheme `Tests-Unit`)
- Build verification
- Deployment to App Store Connect (on release)

## Pull Requests

- Follow the pull request template.
- Include screenshots for UI changes (light **and** dark mode).
- Ensure `bundle exec fastlane lint` passes before submitting.
- Update documentation if adding/changing functionality.
- Translations: only edit English sources (`en.lproj/Localizable.strings`). All other locales are synced from [lokalise.com](https://lokalise.com/public/834452985a05254348aee2.46389241/) — do not edit non-English `.strings` files manually.
- Link related documentation PRs in the `companion.home-assistant` repository.

## Additional Resources

- [Home Assistant Developer Docs](https://developers.home-assistant.io/)
- [Contributing Guidelines](../CONTRIBUTING.md)
- [Code of Conduct](../CODE_OF_CONDUCT.md)
