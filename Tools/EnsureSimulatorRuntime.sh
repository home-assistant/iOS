#!/bin/bash
# Makes sure every registered simulator runtime of a platform is mounted before a test run asks for it.
#
# CoreSimulator's disk-image daemon sometimes unmounts a runtime volume behind a running job and
# does not mount it again. On the xcode-27 runner image it does so while tidying up its duplicate
# watchOS 27.0 registration (actions/runner-images#14946), and the watch tests then fail with
# "The watchOS 27.0 simulator runtime is not available" although `simctl runtime list` still shows
# the disk image as Ready. Ejecting the platform's runtime volumes and restarting the daemons makes
# CoreSimulator mount every registered runtime again, which takes about a second.
#
# Usage: EnsureSimulatorRuntime.sh <platform>, with the platform as `simctl list runtimes` names it
# (iOS, watchOS, tvOS, xrOS).
#
# The recovery needs sudo for the unmount and the daemon restart, which CI runners grant without a
# password. On a developer machine it only prompts when a runtime is actually missing.

set -euo pipefail

PLATFORM="${1:?usage: $(basename "$0") <platform>}"

# `simctl runtime list` lists the disk images, which keep saying Ready after their volume is gone;
# `simctl list runtimes` lists what is mounted. A Ready image whose build is not among the mounted
# runtimes is the broken state.
missing_runtimes() {
  python3 - "$PLATFORM" <<'PY'
import json
import subprocess
import sys

platform = sys.argv[1]
simulator = {"iOS": "iphonesimulator", "watchOS": "watchsimulator", "tvOS": "appletvsimulator", "xrOS": "xrsimulator"}[platform]

def simctl(*arguments):
    # A failing simctl exits this probe nonzero, which the caller treats as "not yet".
    try:
        return json.loads(subprocess.check_output(["xcrun", "simctl", *arguments, "-j"], stderr=subprocess.DEVNULL))
    except subprocess.CalledProcessError:
        sys.exit(1)

images = simctl("runtime", "list").values()
mounted = {
    runtime["buildversion"]
    for runtime in simctl("list", "runtimes")["runtimes"]
    if runtime["isAvailable"] and runtime["platform"] == platform
}
for image in images:
    if image["state"] == "Ready" and image["platformIdentifier"].endswith(simulator) and image["build"] not in mounted:
        print(f"{platform} {image['version']} ({image['build']})")
PY
}

# A probe that fails outright (simctl itself erroring) is not an empty answer: it needs the restart
# just as much, and while polling it means the service is not back yet.
if missing="$(missing_runtimes)"; then
  if [ -z "$missing" ]; then
    echo "Every $PLATFORM simulator runtime is mounted"
    exit 0
  fi
  echo "Not mounted although its disk image is Ready: $missing"
else
  echo "simctl could not list the $PLATFORM simulator runtimes"
fi
echo "Restarting the simulator disk-image daemons"

# A volume the daemon already took down leaves its empty mount point behind, so only eject what is
# still mounted.
for volume in /Library/Developer/CoreSimulator/Volumes/"$PLATFORM"_*; do
  mount | grep -q " on $volume " || continue
  sudo diskutil unmount force "$volume" || true
done
sudo launchctl kill -9 system/com.apple.CoreSimulator.simdiskimaged || true
sudo pkill -9 com.apple.CoreSimulator.CoreSimulatorService || true

for _ in $(seq 1 24); do
  if missing="$(missing_runtimes)" && [ -z "$missing" ]; then
    echo "Every $PLATFORM simulator runtime is mounted again"
    exit 0
  fi
  sleep 5
done

echo "Still not mounted after two minutes: $(missing_runtimes || echo "simctl still failing")" >&2
xcrun simctl list runtimes >&2
exit 1
