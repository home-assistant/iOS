#!/bin/bash
# Boots the newest available simulator of a model in the background, so that its boot overlaps the
# build instead of holding up the test run. Returns as soon as the boot is under way: xcodebuild
# waits for the device itself when the tests start.
#
# Usage: BootSimulator.sh <platform> <model>, with the platform as `simctl list runtimes` names it
# (iOS, watchOS, tvOS, xrOS) and the model as `simctl list devices` names it ("iPhone 17"). The
# device is resolved like the fastlane test lanes resolve theirs: the newest runtime wins.
#
# The boot is a head start, not a requirement: the test lane resolves and boots the device itself,
# with its own runtime recovery, so nothing here fails the job. A runtime CoreSimulator has lost
# (see EnsureSimulatorRuntime.sh) lists no devices, so it is mounted again before looking.

set -uo pipefail

PLATFORM="${1:?usage: $(basename "$0") <platform> <model>}"
MODEL="${2:?usage: $(basename "$0") <platform> <model>}"

if ! "$(dirname "$0")/EnsureSimulatorRuntime.sh" "$PLATFORM"; then
  echo "::warning::The $PLATFORM simulator runtime is not mounted, not booting $MODEL ahead of the tests"
  exit 0
fi

udid=$(xcrun simctl list devices available -j | python3 -c '
import json
import re
import sys

platform, model = sys.argv[1:]
candidates = [
    (tuple(int(number) for number in re.findall(r"\d+", runtime)), device["udid"])
    for runtime, devices in json.load(sys.stdin)["devices"].items()
    if platform in runtime
    for device in devices
    if device["name"] == model
]
if not candidates:
    sys.exit(f"No available {platform} simulator named {model!r}")
print(max(candidates)[1])
' "$PLATFORM" "$MODEL") || {
  echo "::warning::No $PLATFORM simulator named '$MODEL' to boot ahead of the tests"
  exit 0
}

echo "Booting $MODEL ($udid) in the background"
nohup xcrun simctl boot "$udid" >"${RUNNER_TEMP:-${TMPDIR:-/tmp}}/boot-$udid.log" 2>&1 &
