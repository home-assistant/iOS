---
name: ha-ios-testing
description: Unit and snapshot testing conventions. Use when writing tests, mocking dependencies by overriding Current, running the Tests-Unit scheme, or adding snapshot tests for new SwiftUI views.
---

# Testing

## Running Tests

```bash
bundle exec fastlane test
```

Or in Xcode: use the `Tests-Unit` scheme with ⌘U.

## Testing Conventions

- Tests live in `Tests/` mirroring the source structure
- Mock dependencies by overriding `Current.*` properties in test setup
- Use `Sources/SharedTesting/` for shared test utilities
- Tests are excluded from SwiftLint enforcement

## End-to-End Testing

`Tests/UI/OnboardingE2ETests.swift` drives onboarding against a real Home Assistant, from the
welcome screen to the native settings screen the frontend opens over the external message bus. It
runs nightly through the `E2E` workflow, never through `fastlane test`.

- Elements it drives carry an identifier from `AccessibilityIdentifier`
  (`Sources/App/Accessibility/`), which is compiled into both the app and the UI test bundle. Add a
  case there rather than matching on user-facing copy, which translation would break.
- Run it locally with `bundle exec fastlane e2e` against an instance started from
  `.github/e2e/homeassistant`. See [that directory's README](../../../.github/e2e/README.md).

## Snapshot Testing

New SwiftUI views should have snapshot tests using helpers from `SharedTesting`:

```swift
import SharedTesting

func testMyView() {
    assertLightDarkSnapshots(of: MyView()) // tests both light and dark mode
}
```
