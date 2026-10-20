# End-to-end tests

The [`E2E` workflow](../workflows/e2e.yml) runs `Tests/UI/OnboardingE2ETests.swift` against a real
Home Assistant every night at 05:00 UTC, mirroring [home-assistant/android][android-workflow]'s own
`e2e` workflow. The flow onboards the app from the welcome screen, then drives the frontend into
opening the app's **native** settings screen, which is what proves the external message bus works
end to end. An hour later it runs `Tests/UI/RestoredDeviceE2ETests.swift`, in a job of its own
because every flow onboards from scratch on an erased simulator. A manual run picks the flow through
the `test` input.

## The fixture

`homeassistant/` is a Home Assistant configuration directory with its `.storage` pre-seeded, so an
instance started against it comes up already onboarded, with a fixed administrator account:

| Username | Password   |
| -------- | ---------- |
| `citest` | `h7jk99&U` |

It is a copy of the fixture in [home-assistant/android][android-fixture], minus the `go2rtc` config
entry, which needs a binary the container ships and a `pip`-installed core does not. Keeping the two
in step means both apps are tested against the same instance, with the same entities and credentials.

## Running it locally

Start an instance. Use a copy: Home Assistant rewrites `.storage` and writes its database and logs
into whichever config dir it is given. The interpreter has to satisfy core's `requires-python`,
which is 3.14.2 or newer; `pip` refuses the install and names the version it wanted if it is older,
so there is no need to check the patch level up front.

```bash
cp -R .github/e2e/homeassistant /tmp/homeassistant && python3.14 -m venv /tmp/ha && /tmp/ha/bin/pip install homeassistant && /tmp/ha/bin/hass --config /tmp/homeassistant
```

Then run the flow. The lane checks the instance first, walking the same login exchange the app
performs during onboarding, and erases the simulator so the app starts at the welcome screen:

```bash
bundle exec fastlane e2e
```

It takes `url:`, `username:`, `password:` and `device:` options, all defaulting to the fixture above
and an `iPhone 17`, and `test:` to pick which test runs, defaulting to `OnboardingE2ETests`. Each
test onboards from the welcome screen, so only one runs per erased simulator.
`Tests/UI/RestoredDeviceE2ETests.swift` onboards, relaunches the app with
`-E2E_VENDOR_IDENTIFIER` set to another device's identifier, which is what a backup restored onto new
hardware looks like to the app, and sets the device up as a new one from the screen that follows:

```bash
bundle exec fastlane e2e test:RestoredDeviceE2ETests
```

`Tests/UI/RestoredDeviceFlowsRecordingTests.swift` holds the same flows paced for watching, one per test
and each picking up where the one before left off, for recordings rather than the nightly:
`Tools/record_ui_test.sh` runs one of them with `test-without-building`, exports the screen recording XCTest
keeps in the result bundle, and re-encodes it at 30 fps. The device names it relaunches as are unique per
run through `TEST_RUNNER_E2E_RUN_ID`, so a simulator that already ran them can run them again.

```bash
xcodebuild build-for-testing -project HomeAssistant.xcodeproj -scheme Tests-UI -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/DerivedData
export TEST_RUNNER_E2E_RUN_ID=$(date +%H%M)
Tools/record_ui_test.sh "$UDID" Tests-UI/RestoredDeviceFlowsRecordingTests/test1Onboards onboarding.mp4
Tools/record_ui_test.sh "$UDID" Tests-UI/RestoredDeviceFlowsRecordingTests/test2SetsUpAsANewDevice new-device.mp4
```

The two-server flow (`test6SetsUpTwoServersAsANewDevice`) adds a second server first, so it needs a second
instance at `E2E_HOME_ASSISTANT_SECOND_URL` (default `http://localhost:8124`) that Home Assistant tells apart
from the first: a copy of the fixture with another `uuid` in `.storage/core.uuid`, its own `location_name` in
`.storage/core.config`, and `server_port` set to 8124 in the `stable` entry of `.storage/http`. Setting the
port in `configuration.yaml` instead makes it a pending HTTP config, which Home Assistant reverts five minutes
later unless confirmed from its UI, and the instance then fails to restart on the port the first one holds.

To check the instance without running the flow:

```bash
python3 Tools/home_assistant_e2e_auth.py --url http://localhost:8123 --username citest --password 'h7jk99&U' --timeout 300 --require-component mobile_app
```

The iOS Simulator shares the host's network stack, so `http://localhost:8123` is also the address to
type into onboarding by hand on a simulator running on the same machine. This is the one place iOS
has it easier than Android, whose emulators need an egress tunnel and a DNS override to reach the
same instance.

## Keeping the fixture in sync

Nothing enforces that this stays level with Android's copy, so when they regenerate theirs it drifts
silently. To compare:

```bash
for f in $(cd .github/e2e/homeassistant/.storage && ls); do curl -fsS "https://raw.githubusercontent.com/home-assistant/android/main/.github/e2e/homeassistant/.storage/$f" | diff -q - ".github/e2e/homeassistant/.storage/$f" || echo "differs: $f"; done
```

`core.config_entries` is expected to differ: the `go2rtc` entry is deliberately removed here.

## When a run fails

A failing nightly opens an issue titled "E2E: the nightly `<test>` is failing", one per flow,
labelled `automated`, naming the step that failed and linking the run. Later failures are added to
that same issue as comments, and a closed one is reopened, so a bad week leaves one thread to read
rather than seven issues. Only the scheduled run reports: a manual dispatch is usually someone working on the
workflow itself. GitHub's own notification for a failing schedule reaches only whoever last edited
the cron line, which is why this exists.


The `e2e-artifacts` artifact carries a screen recording of the run under `e2e-recording/`, which is
usually the quickest way to see where the flow went wrong. Alongside it are Home Assistant's own log,
the `/api/config` it reported, and the full `.xcresult`.

Recordings are kept for passing runs as well, through `uiTestingScreenshotsLifetime` in
[`Tests-UI.xctestplan`](../../Tests/UI/Tests-UI.xctestplan); Xcode would otherwise discard them on
success. That is what the test plan exists for. It costs roughly 160 MB per run, so the artifact is
kept for 14 days rather than the 90-day default.

## Notes

- The test is not repeatable on a simulator that has already onboarded: it starts from the welcome
  screen, and the location and notification prompts it answers only appear once. Erase the device
  between runs, which is why the lane never retries a failure.
- The elements it drives are identified by `AccessibilityIdentifier`, which is compiled into both
  the app and the UI test bundle, so a rename breaks the build rather than the nightly run. Only the
  frontend's own elements are matched on their copy, since the app does not own those.

[android-workflow]: https://github.com/home-assistant/android/blob/main/.github/workflows/e2e.yml
[android-fixture]: https://github.com/home-assistant/android/tree/main/.github/e2e/homeassistant
