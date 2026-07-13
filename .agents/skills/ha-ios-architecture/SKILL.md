---
name: ha-ios-architecture
description: Home Assistant iOS project layout, build setup, and the "World" dependency-injection pattern. Use when starting work in the repo, deciding where code lives across targets (App, Shared, Watch, CarPlay, Extensions), accessing dependencies through the global `Current`, or setting up dependencies and code signing.
---

# Architecture & Project Layout

Home Assistant for Apple Platforms is a native Swift companion app for [Home Assistant](https://www.home-assistant.io/) home automation. The primary user interaction is through a `WKWebView` displaying the Home Assistant web frontend, with native features for notifications, sensors, location tracking, widgets, CarPlay, Apple Watch, and more.

- **Language**: Swift 5.8+
- **Platforms**: iOS, watchOS, macOS (Catalyst), CarPlay
- **Build System**: Xcode 26.2+, Swift Package Manager
- **Project**: Open `HomeAssistant.xcodeproj` directly (dependencies are managed via Swift Package Manager)

## Getting Started

### Install Dependencies

```bash
bundle install
```

> Third-party dependencies are managed via Swift Package Manager (SPM) and resolved automatically by Xcode. `bundle install` installs the Ruby tooling (Fastlane) used for linting, testing, and CI.

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

## The "World" Pattern (Dependency Injection)

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

## Additional Resources

- [Home Assistant Developer Docs (Apple)](https://developers.home-assistant.io/docs/apple/)
- [Contributing Guidelines](../../../CONTRIBUTING.md)
- [Point-Free: How to Control the World](https://www.pointfree.co/blog/posts/21-how-to-control-the-world)
