#!/bin/bash
#
# Xcode Cloud runs this after every xcodebuild action.
#
# On the Developer ID workflow it zips the notarized app the same way fastlane/lanes/macos.rb does
# and stages it on a draft GitHub release, which is where release_macos.yml picks it up when it is
# dispatched with source: xcode-cloud. Every other workflow falls straight through.

set -euo pipefail

if [ -z "${CI_DEVELOPER_ID_SIGNED_APP_PATH:-}" ]; then
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck source=/dev/null
. Configuration/Version.xcconfig

staging="$(mktemp -d)"
asset="${staging}/home-assistant-mac.zip"

ditto -c -k --sequesterRsrc --keepParent "$CI_DEVELOPER_ID_SIGNED_APP_PATH" "$asset"

./ci_scripts/upload_macos_release_asset.py \
  "$asset" \
  "xcode-cloud/${MARKETING_VERSION}/${CURRENT_PROJECT_VERSION}" \
  "${MARKETING_VERSION} (${CURRENT_PROJECT_VERSION##*.})"

rm -rf "$staging"
