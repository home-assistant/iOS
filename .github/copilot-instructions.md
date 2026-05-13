# GitHub Copilot Instructions for Home Assistant iOS

See [AGENTS.md](../AGENTS.md) for the full AI agent reference. This file provides GitHub Copilot-specific guidance.

## Quick Reference

### Commands

```bash
# Install dependencies
bundle install
bundle exec pod install --repo-update

# Fix lint issues (run before committing)
bundle exec fastlane autocorrect

# Check lint without fixing
bundle exec fastlane lint

# Run tests
bundle exec fastlane test
```

### Key Rules

1. **Dependency Injection**: This project uses the "World" pattern. A global `Current` variable (`AppEnvironment`) holds all dependencies. Never assign to `Current.*` outside test code.
2. **Localization**: Add strings to `Sources/App/Resources/en.lproj/Localizable.strings`. SwiftGen generates type-safe `L10n` accessors on build.
3. **SF Symbols**: Use `SFSafeSymbols` (`Image(systemSymbol: .house)`) not string-based APIs.
4. **CocoaPods only**: No Swift Package Manager. Dependencies via `Podfile`.
5. **Workspace**: Always use `HomeAssistant.xcworkspace`.

### Architecture

- The app is a companion to the Home Assistant web UI displayed in a `WKWebView`
- Native features: notifications, sensors, location, widgets, CarPlay, Apple Watch
- Platforms: iOS, watchOS, macOS (Catalyst), CarPlay
- Shared code in `Sources/Shared/`, platform-specific in `Sources/App/`, `Sources/Watch/`, etc.

### Code Style

- Max line width: 120 characters
- Wrap arguments/parameters: `before-first`
- `self` only in initializers
- No `force_cast` or `force_try`
- Use `guard` for early returns
- SwiftUI preferred for new UI, `@MainActor` on view models

### Testing

- Mock dependencies by overriding `Current.*` in test setup
- Tests in `Tests/` directory mirror source structure
- Use `Sources/SharedTesting/` for shared test utilities
