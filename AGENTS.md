# AI Agent Instructions for Home Assistant iOS

This is the router for AI coding agents (LLMs) working on the Home Assistant for Apple Platforms codebase. Detailed guidance lives in modular skills under [`.agents/skills/`](.agents/skills). Load the skill that matches your task instead of reading everything up front.

Home Assistant for Apple Platforms is a native Swift companion app for [Home Assistant](https://www.home-assistant.io/) home automation. The primary user interaction is through a `WKWebView` displaying the Home Assistant web frontend, with native features for notifications, sensors, location tracking, widgets, CarPlay, Apple Watch, and more.

- **Language**: Swift 5.8+
- **Platforms**: iOS, watchOS, macOS (Catalyst), CarPlay
- **Build System**: Xcode 26.2+, Swift Package Manager
- **Project**: Open `HomeAssistant.xcodeproj` directly (dependencies are managed via Swift Package Manager)

## Skills

| Skill | Load it when you are… |
|-------|-----------------------|
| [`ha-ios-architecture`](.agents/skills/ha-ios-architecture/SKILL.md) | Starting in the repo, deciding where code lives across targets, using the global `Current` (World pattern), or setting up dependencies and code signing |
| [`ha-ios-webview`](.agents/skills/ha-ios-webview/SKILL.md) | Working on `WebViewController`, the JavaScript external message bus, custom URL schemes, or deep links into the frontend |
| [`ha-ios-magicitem`](.agents/skills/ha-ios-magicitem/SKILL.md) | Adding or changing `MagicItem` types or actions shared by Widgets, Watch, CarPlay, and App Shortcuts |
| [`ha-ios-localization`](.agents/skills/ha-ios-localization/SKILL.md) | Adding or changing user-facing strings, using `L10n`, or dealing with Lokalise translations |
| [`ha-ios-code-style`](.agents/skills/ha-ios-code-style/SKILL.md) | Writing or formatting Swift, running SwiftFormat/SwiftLint, referencing SF Symbols or Material Design icons, logging, or using `with()` |
| [`ha-ios-concurrency`](.agents/skills/ha-ios-concurrency/SKILL.md) | Writing async/await, actors, or Combine, deciding whether to touch PromiseKit, or calling the server via HAKit |
| [`ha-ios-persistence`](.agents/skills/ha-ios-persistence/SKILL.md) | Adding or migrating a persistent model, or choosing between GRDB, Realm, and UserDefaults |
| [`ha-ios-push-live-activities`](.agents/skills/ha-ios-push-live-activities/SKILL.md) | Implementing or fixing push notifications or Live Activities across the local-push and remote-push flows |
| [`ha-ios-ui`](.agents/skills/ha-ios-ui/SKILL.md) | Building UI, choosing SwiftUI vs UIKit, or following the one-struct-per-file, inline-body, and `#Preview` rules |
| [`ha-ios-testing`](.agents/skills/ha-ios-testing/SKILL.md) | Writing unit or snapshot tests, or mocking dependencies by overriding `Current` |
| [`ha-ios-workflow-ci`](.agents/skills/ha-ios-workflow-ci/SKILL.md) | Preparing a change for commit or understanding the CI gates that must pass before merge |
| [`ha-ios-skill-maintenance`](.agents/skills/ha-ios-skill-maintenance/SKILL.md) | Adding, editing, or reorganizing these skills, or updating this router |

## Additional Resources

- [Home Assistant Developer Docs (Apple)](https://developers.home-assistant.io/docs/apple/)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Point-Free: How to Control the World](https://www.pointfree.co/blog/posts/21-how-to-control-the-world)
