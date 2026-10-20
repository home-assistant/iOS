#!/bin/sh
#
# Records one UI test on a simulator as a 30 fps video spanning exactly the test.
#
# Usage: Tools/record_ui_test.sh <simulator udid> <Tests-UI/Class/test> <output.mp4> [derived data path]
#
# The test bundle must already be built for that simulator (`xcodebuild build-for-testing -scheme Tests-UI`),
# since this runs `test-without-building`. XCTest records the screen for the test's duration and keeps the
# recording in the result bundle (the Tests-UI test plan keeps it for passing runs too); this exports it and
# re-encodes it at a constant 30 fps. Needs ffmpeg.
#
set -eu

UDID=$1
TEST=$2
OUT=$3
DERIVED_DATA=${4:-build/DerivedData}
WORK=$(mktemp -d)

STATUS=0
xcodebuild test-without-building \
  -project HomeAssistant.xcodeproj \
  -scheme Tests-UI \
  -only-testing:"$TEST" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$WORK/result.xcresult" \
  > "$WORK/test.log" 2>&1 || STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "Test failed (exit $STATUS); log at $WORK/test.log" >&2
  exit "$STATUS"
fi

xcrun xcresulttool export attachments --path "$WORK/result.xcresult" --output-path "$WORK/attachments" >/dev/null
RECORDING=$(python3 - "$WORK/attachments" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
for group in json.loads((out / "manifest.json").read_text()):
    for attachment in group.get("attachments", []):
        if attachment.get("suggestedHumanReadableName", "").lower().endswith(".mp4"):
            print(out / attachment["exportedFileName"])
            sys.exit(0)
sys.exit("No screen recording in the result bundle")
PY
)

# The recording opens on the home screen while the app installs. The app's launch is the first stretch of
# black, so the video starts there; a test that opens on the app already running keeps everything.
LEAD=$(ffmpeg -nostats -i "$RECORDING" -vf "blackdetect=d=0.2:pix_th=0.10" -an -f null - 2>&1 \
  | sed -nE 's/.*black_start:([0-9.]+).*/\1/p' | head -1)
LEAD=${LEAD:-0}

ffmpeg -v error -y -ss "$LEAD" -i "$RECORDING" \
  -vf fps=30 -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart -an "$OUT"
echo "Wrote $OUT (from $LEAD s into the test)"
rm -rf "$WORK"
