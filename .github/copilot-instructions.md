# GitHub Copilot Instructions for Home Assistant iOS

This document provides guidance for GitHub Copilot when working on the Home Assistant iOS application.

## Project Overview

Home Assistant for Apple Platforms is a native iOS, watchOS, and macOS application, with it's main interaction through a WKWebView displaying Home Assistant web app UI, written in Swift that provides a companion app for Home Assistant home automation. The project uses:

- **Language**: Swift 5.8+
- **Minimum iOS version**: Check deployment target in project settings
- **Architecture**: Multi-platform (iOS, watchOS, macOS, CarPlay)
- **Dependencies**: CocoaPods
- **Build system**: Xcode 15.3+

## Code Style and Standards

### Formatting

The project uses automated formatting tools. All code must pass these linters:

- **SwiftFormat**: Enforces consistent code formatting (`.swiftformat` configuration)
  - Max line width: 120 characters
  - Use `before-first` wrapping style for arguments, parameters, and collections
  - `self` keyword only in initializers
  - Guard else on same line
  
- **SwiftLint**: Enforces Swift code quality rules (`.swiftlint.yml` configuration)
  - Enabled rules include: cyclomatic_complexity, force_cast, force_try, unused_optional_binding, weak_delegate
  - Custom rule: Do not assign to `Current` environment variables outside of tests
  - Custom rule: Use `SFSafeSymbols` via `systemSymbol` parameters instead of string-based system image names

- **Rubocop**: For Ruby/Fastlane files
- **YamlLint**: For YAML configuration files

### Swift Conventions

- Use Swift's modern language features (async/await, Combine where appropriate)
- Prefer value types (structs) over reference types (classes) when appropriate
- Use proper access control (`private`, `fileprivate`, `internal`, `public`)
- Avoid force unwrapping (`!`) and force casting unless absolutely necessary
- Use guard statements for early returns
- Keep cyclomatic complexity low (use helper methods to break down complex logic)

### SFSymbols Usage

Always use `SFSafeSymbols` library for type-safe SF Symbol references instead of string-based APIs:

```swift
// ❌ Avoid
Image(systemName: "house")

// ✅ Prefer
Image(systemSymbol: .house)
```

### Environment Variables

Do not assign to `Current` environment variables outside of test code. This is enforced by a custom SwiftLint rule.

## Project Structure

- `Sources/App` - Main iOS application
- `Sources/Shared` - Shared code between platforms (iOS, watchOS, macOS)
- `Sources/Watch` - watchOS specific code
- `Sources/MacBridge` - macOS specific code
- `Sources/CarPlay` - CarPlay integration
- `Sources/Extensions` - App Extensions (widgets, notifications, etc.)
- `Tests/` - Test files
- `Configuration/` - Build configuration files

## Building and Testing

### Initial Setup

```bash
# Install dependencies via Bundler and CocoaPods
bundle install
bundle exec pod install --repo-update
```

### Code Signing

Debug builds use Automatic provisioning. Create `Configuration/HomeAssistant.overrides.xcconfig`:

```
DEVELOPMENT_TEAM = YourTeamID
BUNDLE_ID_PREFIX = some.bundle.prefix
```

### Linting

```bash
# Check for linting problems
bundle exec fastlane lint

# Auto-fix linting problems
bundle exec fastlane autocorrect
```

### Running Tests

Open `HomeAssistant.xcworkspace` in Xcode and run tests using the Test navigator (⌘U) or run scheme-specific tests.

## Common Patterns

### Dependency Injection

The project uses a dependency injection pattern via the `Current` environment object for testability. Access shared services through this interface.

### Networking

Use the existing `HAConnectionInfo` and related APIs for communicating with Home Assistant servers. Networking code is in `Sources/Shared/Networking`.

### Data Persistence

Use the existing database layer in `Sources/Shared/Database` for storing persistent data.

### UI Design

- Follow Apple's Human Interface Guidelines
- Support both light and dark mode
- Use SwiftUI where appropriate, UIKit where needed for older patterns
- Material Design Icons are available via the `MaterialDesignIcons` integration

## Testing

- Write unit tests for business logic
- Follow existing test patterns in the `Tests/` directory
- Mock external dependencies using the test environment setup
- Tests exclude SwiftLint enforcement but should still follow Swift best practices

## Dependencies

Dependencies are managed via CocoaPods. Add new dependencies sparingly and discuss in PR reviews.

## Continuous Integration

CI runs on GitHub Actions:
- Linting (SwiftFormat, SwiftLint, Rubocop, YamlLint)
- Unit tests
- Build verification
- Deployment to App Store Connect (on release)

## Pull Requests

- Follow the pull request template
- Include screenshots for UI changes (light and dark mode)
- Ensure all linters pass
- Update documentation if adding/changing functionality
- Link related documentation PRs in companion.home-assistant repository

## Additional Resources

- [Apple Swift Programming Language](https://www.apple.com/swift/)
- [Home Assistant Developer Docs](https://developers.home-assistant.io/)
- [Contributing Guidelines](../CONTRIBUTING.md)
- [Code of Conduct](../CODE_OF_CONDUCT.md)
