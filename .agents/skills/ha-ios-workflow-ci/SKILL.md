---
name: ha-ios-workflow-ci
description: The end-to-end change workflow, TestFlight feature gating, and CI gates. Use when preparing a change for commit, understanding the order of lint/autocorrect/test steps, gating a feature behind TestFlight with `Current.isTestFlight`, or knowing what GitHub Actions checks before a PR can merge.
---

# Workflow & Continuous Integration

## Workflow Summary

1. **Install dependencies**: `bundle install` (SPM dependencies resolve automatically in Xcode)
2. **Make your changes** in the appropriate `Sources/` directory
3. **Add strings** to `en.lproj/Localizable.strings` if needed (SwiftGen generates accessors on build; see the `ha-ios-localization` skill)
4. **Run autocorrect**: `bundle exec fastlane autocorrect` (see the `ha-ios-code-style` skill)
5. **Run tests**: `bundle exec fastlane test` (see the `ha-ios-testing` skill)
6. **Commit** your changes

## TestFlight-Gated Features

A feature that is not ready for every user yet may ship to beta testers only. Two rules govern this, and both are mandatory.

### 1. `Current.isTestFlight` is the only gate

```swift
case .remindersSync:
    // Labs feature, limited to TestFlight builds while it matures.
    return Current.isTestFlight
```

- Gate on `Current.isTestFlight` (defined in `Sources/Shared/Environment/Environment.swift`) and nothing else. Do not invent a feature-flag type, add a build setting, an `#if` branch, an `Info.plist` key, or a hidden setting to accomplish the same thing.
- Read `Current.isTestFlight`; never assign to it outside tests (see the `ha-ios-architecture` skill for the `Current` rules, and the `ha-ios-testing` skill for overriding it in tests).
- Keep the gate at the smallest edge that hides the feature — one availability check, menu entry, or settings row — rather than scattering the condition through the implementation. Removing the gate should be a small, obvious diff.
- Add a short comment next to the gate saying why the feature is beta-only, as in the example above.

### 2. Every gate ships with a parallel draft PR that removes it

Whenever a change puts a feature behind `Current.isTestFlight`, a second, parallel **draft** PR must exist that removes that gate:

- Branch it off the gating PR's branch, so its diff is exactly the gate removal and nothing else.
- Title it so its purpose is obvious, e.g. `Ungate <feature> from TestFlight`, and mark it as a draft — it is merged only once the feature is ready for general release.
- Link the two PRs to each other in their descriptions.
- When the gating PR changes during review, update the ungating PR to match, so it stays mergeable.

The point is that graduating a feature out of beta is a one-click merge instead of an archaeology exercise: an unpaired gate tends to outlive the reason it was added.

> Per the [AI policy](../../../AI_POLICY.md), agents do not open PRs autonomously. Prepare the ungating branch and hand both PRs to a human to review and submit.

## Continuous Integration

CI runs on GitHub Actions (`.github/workflows/ci.yml`):

- **Linting**: SwiftFormat, SwiftLint, Rubocop, YamlLint
- **Unit Tests**: Runs the `Tests-Unit` scheme
- **Build Verification**: Ensures the app builds cleanly
- **Patch coverage**: At least 90% of the lines a PR changes must be covered by the unit tests

All lint checks and tests must pass before a PR can be merged.

### The 90% patch coverage gate

The `patch-coverage` job measures how much of a pull request's *own* diff the unit tests
execute — not the coverage of the project as a whole, which is tracked separately by the
Codecov statuses in `codecov.yaml`. Below 90%, the job fails and `github-actions[bot]`
submits a **changes-requested review** naming the shortfall; the per-file breakdown and the
list of changed lines no test runs are in the run's job summary.

`Tools/diff_coverage.py` computes the number from the LCOV tracefile that
`Tools/xccov_to_lcov.py` writes out of the test run's `.xcresult`, and the same script
reproduces the CI verdict locally:

```bash
bundle exec fastlane test
python3 Tools/xccov_to_lcov.py fastlane/test_output/Tests-Unit.xcresult \
  --lcov fastlane/test_output/coverage.lcov
python3 Tools/diff_coverage.py fastlane/test_output/coverage.lcov --base origin/main
```

What counts, and what does not:

- Only lines the coverage report marks executable count, so comments, declarations and
  braces never drag the number down.
- Files no target in the `Tests-Unit` scheme builds have no coverage data and are skipped
  entirely — a watchOS-only or widget-only file cannot fail the gate.
- `Tests`, `Sources/SharedTesting` and the `Resources` directories are excluded, matching
  the `ignore` list in `codecov.yaml`. Keep the two lists in step.
- A pull request that changes nothing coverable (docs, assets, project settings) passes.
- A run with no tracefile to read, because the tests or the conversion failed, skips the
  gate and dismisses any request an earlier run left behind.

Pushing tests that cover the missing lines dismisses the review automatically. When new
code genuinely cannot be unit tested — UIKit plumbing, a system framework wrapper — a
maintainer dismisses the review to let the change land; write the reason into the PR
description so the next reader knows why.
