#!/bin/bash
# Turns the app a test build leaves in DerivedData into one that installs and runs on its own.
#
# The test run puts its test bundle inside the app, and turns package products shared with a test
# target (Sodium, through Shared and Tests-Shared) into frameworks it leaves in PackageFrameworks
# for the test runner. The app target does not embed those because it does not link them itself,
# so the app only launches under Xcode, which points it at the build folder; a copy installed
# anywhere else crashes at launch with "Library not loaded". This copies the app to the
# destination folder, drops the test bundles and embeds the package frameworks it is missing.
#
# Usage: PrepareSimulatorApp.sh <app> <destination folder> [package frameworks folder]
# The package frameworks folder defaults to PackageFrameworks next to the app.

set -euo pipefail

source_app="$1"
destination="$2"
source_frameworks="${3:-$(dirname "$source_app")/PackageFrameworks}"

rm -rf "$destination"
mkdir -p "$destination"
cp -R "$source_app" "$destination/"
app="$destination/$(basename "$source_app")"
frameworks="$app/Frameworks"

find "$app/PlugIns" -maxdepth 1 -name '*.xctest' -exec rm -rf {} + 2>/dev/null || true

missing_frameworks() {
    find "$app" -type f -perm -u+x -print0 |
        while IFS= read -r -d '' binary; do
            otool -L "$binary" 2>/dev/null | sed -nE 's#^[[:space:]]*@rpath/([^/]+\.framework)/.*#\1#p'
        done |
        sort -u |
        while read -r name; do
            [[ -e "$frameworks/$name" ]] || echo "$name"
        done
}

mkdir -p "$frameworks"
while true; do
    missing="$(missing_frameworks)"
    [[ -z "$missing" ]] && break

    embedded=0
    while read -r name; do
        if [[ -d "$source_frameworks/$name" ]]; then
            cp -R "$source_frameworks/$name" "$frameworks/"
            codesign --force --sign - --timestamp=none "$frameworks/$name" 2>/dev/null
            echo "Embedded $name"
            embedded=1
        fi
    done <<< "$missing"

    if [[ $embedded == 0 ]]; then
        echo "::warning::$(basename "$app") links frameworks that are not in $source_frameworks: $(echo "$missing" | tr '\n' ' ')"
        break
    fi
done
