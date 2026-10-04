#!/bin/bash
# Temporary, CI only: stores every screenshot as a git blob, which creates no branch or tag, then a
# manifest of them the same way, and prints the manifest's SHA so the images can be fetched by API.
set -euo pipefail

manifest="${RUNNER_TEMP:-/tmp}/snapshots/manifest.txt"
: > "$manifest"
for image in "${RUNNER_TEMP:-/tmp}"/snapshots/*/*.png; do
  label=$(basename "$(dirname "$image")")
  sha=$(base64 -i "$image" | gh api "repos/$GITHUB_REPOSITORY/git/blobs" \
    -F content=@- -f encoding=base64 --jq .sha)
  echo "SNAPSHOT $label/$(basename "$image" .png) $sha" >> "$manifest"
done
wc -l < "$manifest"
sha=$(base64 -i "$manifest" | gh api "repos/$GITHUB_REPOSITORY/git/blobs" \
  -F content=@- -f encoding=base64 --jq .sha)
echo "MANIFEST $sha"
