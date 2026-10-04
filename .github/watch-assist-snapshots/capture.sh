#!/bin/bash
# Temporary, CI only: builds the watch app and screenshots the Assist recording screen in each
# scenario on the smallest and the largest watch simulator. Usage: capture.sh <label>
set -euo pipefail

label="$1"
out="${RUNNER_TEMP:-/tmp}/snapshots/$label"
mkdir -p "$out"
scenarios=(tap-0 release-0 tap-60 release-60 tap-100 release-100)

echo "Building the watch app ($label)"
if ! xcodebuild build \
  -project HomeAssistant.xcodeproj \
  -scheme WatchApp \
  -configuration Debug \
  -destination 'generic/platform=watchOS Simulator' \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  -disableAutomaticPackageResolution \
  COMPILER_INDEX_STORE_ENABLE=NO > "$out/build.log" 2>&1; then
  grep -n "error:" "$out/build.log" | head -50 || true
  tail -100 "$out/build.log"
  exit 1
fi

app=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 6 \
  -path "*/Build/Products/Debug-watchsimulator/HomeAssistant-WatchApp.app" | head -1)
bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
echo "Built $app ($bundle)"

# The smallest and the largest watch of the newest watchOS runtime, as "<udid> <name>" lines.
devices=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
runtimes = json.load(sys.stdin)["devices"]
watch = {k: v for k, v in runtimes.items() if "watchOS" in k and v}
newest = max(watch, key=lambda k: [int(n) for n in re.findall(r"\d+", k.split("watchOS")[-1])])
sized = [(int(re.search(r"\((\d+)mm\)", d["name"]).group(1)), d) for d in watch[newest]
         if re.search(r"\((\d+)mm\)", d["name"])]
sized.sort(key=lambda pair: pair[0])
for _, device in {id(d): (s, d) for s, d in (sized[0], sized[-1])}.values():
    print(device["udid"], device["name"])
')
echo "$devices"

while read -r udid name; do
  slug=$(echo "$name" | tr -cd '[:alnum:]')
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b > /dev/null
  xcrun simctl install "$udid" "$app"
  for scenario in "${scenarios[@]}"; do
    xcrun simctl launch --terminate-running-process "$udid" "$bundle" -AssistSnapshot "$scenario" > /dev/null
    sleep 7
    xcrun simctl io "$udid" screenshot --type=png "$out/$slug-$scenario.png" > /dev/null 2>&1
    echo "Captured $label $name $scenario"
  done
done <<< "$devices"
