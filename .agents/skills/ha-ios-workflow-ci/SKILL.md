---
name: ha-ios-workflow-ci
description: The end-to-end change workflow, TestFlight feature gating, companion documentation PRs, and CI gates. Use when preparing a change for commit or a PR, understanding the order of lint/autocorrect/test steps, gating a feature behind TestFlight with `Current.isTestFlight`, opening the matching draft PR in the companion.home-assistant docs repo for a user-facing change, or knowing what GitHub Actions checks before a PR can merge.
---

# Workflow & Continuous Integration

## Workflow Summary

1. **Install dependencies**: `bundle install` (SPM dependencies resolve automatically in Xcode)
2. **Make your changes** in the appropriate `Sources/` directory
3. **Add strings** to `en.lproj/Localizable.strings` if needed (SwiftGen generates accessors on build; see the `ha-ios-localization` skill)
4. **Run autocorrect**: `bundle exec fastlane autocorrect` (see the `ha-ios-code-style` skill)
5. **Run tests**: `bundle exec fastlane test` (see the `ha-ios-testing` skill)
6. **Commit** your changes
7. **Open the documentation draft PR** if the change is user-facing (see [Documentation PRs](#documentation-prs))

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

## Documentation PRs

User-facing documentation for the app lives in a separate repo, [home-assistant/companion.home-assistant](https://github.com/home-assistant/companion.home-assistant) (Docusaurus, default branch `master`). Whenever a code change adds, changes, or removes something a user can see or configure, a **draft** PR in that repo must accompany the app PR. The app's PR template already has a `Documentation: home-assistant/companion.home-assistant#` line for it.

### When a docs PR is needed

Open one when the change:

- Adds a feature, setting, screen, sensor, widget, control, App Intent, notification capability, or platform integration (Watch, CarPlay, Mac, widgets).
- Changes how an existing feature behaves, where it lives in the UI, what it is called, or what it requires (iOS version, permission, server version).
- Removes or deprecates something the docs describe.

No docs PR is needed for refactors, bug fixes that restore documented behavior, test or CI changes, dependency bumps, or internal tooling. If unsure, search the docs repo for the feature's name: if the docs describe the thing you changed, they need to change too.

### How to prepare it

1. Clone or update the docs repo next to this one and branch off `master`.
2. Edit the relevant page under `docs/<area>/` (for example `docs/carplay/`, `docs/apple-watch/`, `docs/notifications/`, `docs/core/`). A new page also needs an entry in `sidebars.js`.
3. Follow the repo's own `.github/copilot-instructions.md`: sentence-case headings, active voice, second person, **bold** for UI strings, _italics_ instead of ALL CAPS. Use the exact UI labels from `en.lproj/Localizable.strings`.
4. Mark anything not yet in a stable release, including every TestFlight-gated feature, with `<span class='beta'>BETA</span>`. Remove the flag only once the stable release that contains the feature's ungating PR (see above) has shipped.
5. Open it as a **draft**, filling in the docs repo's PR template without deleting any of it: under **Type of change** tick "Document new or changing features for which there is an existing pull request elsewhere", and link the app PR under **Additional information**.
6. Put the docs PR number into the app PR's `Documentation:` line, so the two PRs link to each other.
7. When the app PR changes during review in a way users would notice, update the docs PR to match.

The docs PR stays a draft until the app change is merged and released; a human marks it ready for review.

> Per the [AI policy](../../../AI_POLICY.md), a human must review and understand every PR before it is submitted, and agents never open PRs on their own initiative. Open the docs draft only when the developer has asked you to open the app PR, and in the same step. Otherwise, prepare the docs branch and PR text and hand them to the developer to review and submit, as with the ungating PR above. In both cases, leave the AI-usage checkboxes in both templates for the developer to fill in.

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

The review is not posted by the CI run itself: a pull request from a fork runs with a
read-only token. The job uploads its numbers and the pull request number as the
`patch-coverage-<attempt>` artifact, and the
separate `Patch coverage review` workflow (`.github/workflows/patch_coverage_review.yml`),
triggered by `workflow_run` when CI completes, requests or dismisses the review with a token
that can write to any pull request. Like every `workflow_run` workflow, it runs the copy on
`main`, so a change to it only takes effect once merged.

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
