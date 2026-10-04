#!/bin/bash
# Temporary, CI only: stores every screenshot as a git blob, which creates no branch or tag, and
# prints each blob's SHA so the images can be fetched through the API.
set -euo pipefail

for image in "${RUNNER_TEMP:-/tmp}"/snapshots/*/*.png; do
  label=$(basename "$(dirname "$image")")
  sha=$(base64 -i "$image" | gh api "repos/$GITHUB_REPOSITORY/git/blobs" \
    -F content=@- -f encoding=base64 --jq .sha)
  echo "SNAPSHOT $label/$(basename "$image" .png) $sha"
done
