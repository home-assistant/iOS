# End-to-end tests

The [`E2E` workflow](../workflows/e2e.yml) runs `Tests/UI/OnboardingE2ETests.swift` against a real
Home Assistant every night, mirroring [home-assistant/android][android-workflow]'s own `e2e`
workflow. The flow onboards the app from the welcome screen, then drives the frontend into opening
the app's **native** settings screen, which is what proves the external message bus works end to
end.

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
which is 3.14.2 or newer.

```bash
cp -R .github/e2e/homeassistant /tmp/homeassistant && python3.14 -m venv /tmp/ha && /tmp/ha/bin/pip install homeassistant && /tmp/ha/bin/hass --config /tmp/homeassistant
```

Then run the flow. The lane checks the instance first, walking the same login exchange the app
performs during onboarding, and erases the simulator so the app starts at the welcome screen:

```bash
bundle exec fastlane e2e
```

It takes `url:`, `username:`, `password:` and `device:` options, all defaulting to the fixture above
and an `iPhone 17`. To check the instance without running the flow:

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

## Notes

- The test is not repeatable on a simulator that has already onboarded: it starts from the welcome
  screen, and the location and notification prompts it answers only appear once. Erase the device
  between runs, which is why the lane never retries a failure.
- The elements it drives are identified by `AccessibilityIdentifier`, which is compiled into both
  the app and the UI test bundle, so a rename breaks the build rather than the nightly run. Only the
  frontend's own elements are matched on their copy, since the app does not own those.

[android-workflow]: https://github.com/home-assistant/android/blob/main/.github/workflows/e2e.yml
[android-fixture]: https://github.com/home-assistant/android/tree/main/.github/e2e/homeassistant
