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

## Keeping Tests Stable on CI

The CI runner is far slower and busier than a Mac, and `fastlane test` runs the whole `Tests-Unit`
bundle in one process where Swift Testing suites run in parallel with each other and with the
XCTest suites. What flakes locally once a year flakes there every day.

- **Swift Testing suites that swap anything on `Current` must be `@Suite(.serialized)`**, and must
  not assert on side effects of global state (an `objectWillChange` count, "nothing was published"):
  another suite is swapping the same globals at the same moment. Assert on the object under test.
- **Never wait a fixed time** (`asyncAfter(0.2)`, `Task.sleep(120ms)`) for something asynchronous
  to land. Poll for the condition with a deadline of about 30 seconds, through
  `expectation(for: NSPredicate ...)` or a `waitUntil` loop. A short `wait(for:timeout:)` is only
  right for an inverted expectation.
- **A wait that can fail must not be followed by an `await` that only completes when it passed**
  (a gate the test releases by count, a request the test answers by index). Bail out and release
  everything, or the test hangs the job instead of failing it.
- **The test process runs with `ImmediateBackgroundTaskRunner`** as `Current.backgroundTask`: the
  production `ProcessInfoBackgroundTaskRunner` parks a GCD worker per webhook send, and the
  sensor fan-out from tests that flip enablement used to exhaust the pool and freeze every suite
  until the 90-minute job limit. Tests that need another runner swap one in and restore it.
- **`fastlane test` retries a failed test** (`number_of_retries`) and fails a test that runs past
  `-default-test-execution-time-allowance`. Neither excuses a test that is wrong often; a retried
  test still shows as mixed in the result bundle, so fix what it points at.

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
