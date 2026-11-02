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
- Mock dependencies by overriding `Current.*` properties in test setup; a Swift Testing suite that does so carries `.isolatedEnvironment` or `.sharedState` (see below)
- Use `Sources/SharedTesting/` for shared test utilities
- Tests are excluded from SwiftLint enforcement

## Parallel Tests and Shared State

The `Tests-Unit` scheme runs in parallel at two levels, and each has its own rule.

**XCTest classes run in several processes at once.** Both unit test targets are
`parallelizable` in the scheme, so Xcode spreads XCTest classes over worker processes when you run
the tests locally. `fastlane test` turns that off (`parallel_testing: false`): on CI a second
simulator clone could fail to launch the host app, and Swift Testing, where most of the time is
spent, already runs concurrently inside the one host. Each worker has its own
`Current`, and XCTest runs one class at a time inside it, so a class that swaps `Current.*` in
`setUp` and restores it in `tearDown` is safe from the classes in its own process. Within one
bundle the XCTest phase finishes before the Swift Testing phase starts; the two never overlap.

What the workers do share is the simulator. `Tests-Shared` has no host app, and several of its
xctest processes run on the same simulator at once, so they share its app group defaults (one
plist for the whole simulator), the app group container, and files such as the notification
history. A class that writes those, or wipes them with `SensorEnablementStore.resetForTesting()`,
lands in the middle of a class running in another process. Point `Current.settingsStore` at a
defaults suite of the class's own with `PrivateSettingsStore` from `SharedTesting`: create it
first in `setUp` and call `restore()` last in `tearDown`. Give file-backed stores a file of the
test's own (`NotificationHistoryStore(fileURL:)`). Code that opens
`UserDefaults(suiteName: AppConstants.AppGroupID)` directly, rather than through
`Current.settingsStore.prefs`, still reaches the shared suite.

**Swift Testing runs suites and tests concurrently in one process.** Every test shares that
process's `Current`, `UserDefaults`, app database, keychain and singletons. `.serialized` does not
help: it only keeps the tests of one suite apart from each other, and two suites that both swap
`Current.servers` still overlap. A test that changes shared state declares how it is kept apart,
with one of the traits in `SharedTesting`:

- `@Suite(.isolatedEnvironment)` gives each test case a fresh `AppEnvironment` through
  `withCurrent`, so its assignments to `Current.*` are invisible to every other test and it keeps
  running in parallel. Use it for new tests. The override is task-local: it reaches everything the
  test calls and its structured child tasks, but not work that hops to a dispatch queue, a
  PromiseKit callback or `Task.detached`; those read the global environment, which no isolated test
  changes. `.isolatedEnvironment { $0.isTestFlight = false }` configures the environment up front.
- `@Suite(.sharedState)` runs each test case under `SharedStateLock`, so it never overlaps another
  `.sharedState` test in any suite. Use it when the code under test still crosses a queue hop, or
  when the test writes `UserDefaults`, the database, the keychain or a singleton. It subsumes
  `.serialized`.

Swift Testing files that assign to `Current` without either trait fail
`Tools/check_test_isolation.py`, which `fastlane lint` and the CI lint job run. XCTest classes are
not checked. Whatever the trait, assert on the object under test, never on side effects of global
state (an `objectWillChange` count, "nothing was published").

### Nothing a test creates may outlive it

`.sharedState` restores the members of `Current` a test replaced (`CurrentSnapshot`), and XCTest
classes that swap `Current.servers` can do the same with `CurrentSnapshot()` in `setUp` and
`restore()` in `tearDown`. That does not reach objects held elsewhere. XCTest keeps every test case
instance until the process ends, so whatever a class stores in a property during `setUp` lives on
unless `tearDown` sets it to `nil`, and a `HAMockConnection` request the test never answers keeps
its API in a retain cycle (clear `pendingRequests` and `pendingSubscriptions`). Every
`HomeAssistantAPI` observes `Current.sensors`, so each leaked one reads every sensor provider, on the
main thread, whenever anything signals the container, and keeps retrying the update against its
fake server. A few hundred of them once stretched the app's Swift Testing phase from six minutes to
over twenty.

A test that turns sensors on or off gives itself a container (`Current.sensors = SensorContainer()`
under `.sharedState`) instead of signaling the app's. `.sharedState` names any test that signals the
app's container, and any test that holds the shared-state lock for more than five seconds, in the
test log.

### Effects inside `#expect`

Write `await` and `try` before the macro, not inside it: `await #expect(model.load())`,
`try await #require(value())`. The repository's SwiftFormat hoists them out of the call and turns
`#expect(await x)` into `#expectawait (x)` (and `#expect(try x)` into `#expecttry (x)`), which does
not compile.

### Keeping Tests Stable on CI

The CI runner is far slower and busier than a Mac. What flakes locally once a year flakes there
every day.

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
