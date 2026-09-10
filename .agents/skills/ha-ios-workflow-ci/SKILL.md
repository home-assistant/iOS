---
name: ha-ios-workflow-ci
description: The end-to-end change workflow, TestFlight feature gating, CI gates, and the manual Xcode Cloud path. Use when preparing a change for commit, understanding the order of lint/autocorrect/test steps, gating a feature behind TestFlight with `Current.isTestFlight`, knowing what GitHub Actions checks before a PR can merge, or building and shipping through Xcode Cloud when the runners lack the Xcode you need.
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

## Xcode Cloud, for when the runners lack the Xcode you need

`ci.yml` and `distribute.yml` pin `DEVELOPER_DIR` to a specific Xcode on the GitHub-hosted
runner image. Every year the image lags Apple by weeks around the new OS release, and during
that window there is no way to compile against the new SDK on Actions. Xcode Cloud is the
standby for that: it offers `Latest Release`, `Latest Beta` and specific versions on Apple's
own schedule.

Nothing about it runs automatically. Every workflow has a **manual** start condition, so
Actions remains the pipeline of record and Xcode Cloud costs nothing until you reach for it.

### What is in the repo

| Path | Role |
|------|------|
| `Configuration/HomeAssistant.cloudsigning.xcconfig` | Automatic signing, because Xcode Cloud will not App Store-sign a manually signed project |
| `ci_scripts/ci_pre_xcodebuild.sh` | Copies that file to the gitignored `HomeAssistant.cloud.xcconfig`, which `HomeAssistant.release.xcconfig` optionally includes, and stamps the build number |
| `ci_scripts/ci_post_xcodebuild.sh` | Zips the notarized Developer ID app and stages it on a draft GitHub release |
| `ci_scripts/upload_macos_release_asset.py` | The GitHub API half of that upload |

Because the include target only ever exists on an Xcode Cloud machine, local builds,
`fastlane ios build` and `distribute.yml` all keep signing manually against the profiles in
`Configuration/Provisioning`. Nothing about the Actions path changed.

### The four workflows

All four use the shared `App-Release` scheme, the `Release` configuration, and a shared
custom Xcode alias so raising the toolchain is one edit rather than four.

| Workflow | Platform | Action | Post-action |
|----------|----------|--------|-------------|
| New SDK check | iOS | Build + Test | none |
| iOS App Store | iOS | Archive, TestFlight and App Store | TestFlight |
| macOS App Store | macOS | Archive, TestFlight and App Store | TestFlight |
| macOS Developer ID | macOS | Archive, Developer ID | Notarize |

"New SDK check" involves no signing at all, since simulator builds skip provisioning. It is
the cheap one to run repeatedly through beta season, and it is what surfaces SDK-level
breakage (the Xcode 27 RealmSwift `@State` macro, the `.calendar` App Schema domain) while
there is still time to do something about it.

### Build numbers

App Store Connect keeps one build train per marketing version, so the two pipelines must not
fight over it. `distribute.yml` produces `2026.<GITHUB_RUN_NUMBER>`, while `CI_BUILD_NUMBER`
starts at 1 on a new Xcode Cloud product. `XC_BUILD_OFFSET`, an Xcode Cloud environment
variable, lifts the Xcode Cloud numbers clear:

1. Run "New SDK check" once and note the `CI_BUILD_NUMBER` it reports, call it `N`.
2. Look up the latest `distribute.yml` run number, call it `R`.
3. Set `XC_BUILD_OFFSET` to `R + 10 - N`.

Later runs increment from there on their own. Keep the margin small (`R + 10`, never
`R + 900000`): while the Xcode Cloud numbers sit above the Actions ones, Actions cannot ship
again *within that same marketing version*. `MARKETING_VERSION` rolls monthly so the train
resets by itself, and bumping the base `CURRENT_PROJECT_VERSION` in
`Configuration/Version.xcconfig` forces a reset sooner.

### Shipping a release from Xcode Cloud

1. Point the Xcode alias at the version you need.
2. Run "New SDK check" and fix whatever the new SDK broke.
3. Set `XC_BUILD_OFFSET` as above.
4. Run the archive workflows. The two App Store ones deliver to TestFlight themselves.
5. For the Mac direct download, dispatch `tag_macos_release.yml` with `source: xcode-cloud`.
   `release_macos.yml` also auto-detects: it looks for a draft release tagged
   `xcode-cloud/<version>/<build>` and falls back to Distribute artifacts when there is
   none, so a plain `release/*/*` tag push still does the right thing.

The staging draft is left in place on purpose, so re-running `release_macos.yml` still finds
its asset. Delete it by hand once the real release is published.

### Watch for

- The entitlements `Configuration/Entitlements/activate_special_entitlements.sh` injects
  (critical alerts, push provider, thread credentials, both CarPlay ones, device name) live
  in no `.entitlements` file. Codesign only accepts them if the cloud-minted profile carries
  them too, and a mismatch shows up as `0xe8008015` at install time rather than as a build
  failure. The script also skips every one of them when `$CI` is set and the configuration is
  not `Release`, which is why the archive workflows must stay on `Release`.
- `DEVELOPMENT_TEAM` is hardcoded in `Configuration/HomeAssistant.xcconfig` and an Xcode Cloud
  product binds to one App Store Connect team. Both the product and the GitHub authorisation
  need redoing if the team changes.
