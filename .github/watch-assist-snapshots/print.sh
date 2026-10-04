#!/bin/bash
# Temporary, CI only: prints every captured screenshot as base64 into the log, which is the one place
# they can be read back from.
set -euo pipefail

for image in "${RUNNER_TEMP:-/tmp}"/snapshots/*/*.jpg; do
  label=$(basename "$(dirname "$image")")
  echo "=== SNAPSHOT $label-$(basename "$image" .jpg) ==="
  base64 -i "$image" -b 900
  echo "=== END ==="
done
