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

## Snapshot Testing

New SwiftUI views should have snapshot tests using helpers from `SharedTesting`:

```swift
import SharedTesting

func testMyView() {
    assertLightDarkSnapshots(of: MyView()) // tests both light and dark mode
}
```
