#!/bin/bash
#
# Xcode Cloud runs this before every xcodebuild action.
#
# 1. Switches the Release configuration over to cloud-managed signing, which Xcode Cloud requires
#    for anything it archives. See Configuration/HomeAssistant.cloudsigning.xcconfig.
# 2. Stamps the build number the way setup_ha_ci does on GitHub Actions, using CI_BUILD_NUMBER in
#    place of GITHUB_RUN_NUMBER.
#
# XC_BUILD_OFFSET lifts the build number above the ones GitHub Actions is producing, so both
# pipelines can upload to the same version train. See the runbook in
# .agents/skills/ha-ios-workflow-ci/SKILL.md.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "error: CI_BUILD_NUMBER is not set, this script only runs on Xcode Cloud" >&2
  exit 1
fi

cp Configuration/HomeAssistant.cloudsigning.xcconfig Configuration/HomeAssistant.cloud.xcconfig
echo "Enabled cloud-managed signing for the Release configuration"

# shellcheck source=/dev/null
. Configuration/Version.xcconfig

# Only the leading component is the committed base, so re-running this leaves the result unchanged.
version_base="${CURRENT_PROJECT_VERSION%%.*}"
build="${version_base}.$((CI_BUILD_NUMBER + ${XC_BUILD_OFFSET:-0}))"

printf 'MARKETING_VERSION=%s\nCURRENT_PROJECT_VERSION=%s\n' "$MARKETING_VERSION" "$build" \
  > Configuration/Version.xcconfig

echo "Building ${MARKETING_VERSION} (${build})"
