#!/bin/sh -e
# Copies the Firebase configuration of the selected Apple account into the app bundle.
# GOOGLE_SERVICE_INFO_DIR comes from Configuration/Accounts/<account>.xcconfig.

if [ -z "${GOOGLE_SERVICE_INFO_DIR:-}" ]; then
  echo "error: GOOGLE_SERVICE_INFO_DIR is not set; check Configuration/Account.xcconfig" >&2
  exit 1
fi

source_dir="${SRCROOT}/${GOOGLE_SERVICE_INFO_DIR}"
destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$destination"

for name in GoogleService-Info-Debug GoogleService-Info-Release; do
  if [ ! -f "${source_dir}/${name}.plist" ]; then
    echo "error: ${source_dir}/${name}.plist is missing" >&2
    exit 1
  fi
  cp "${source_dir}/${name}.plist" "${destination}/${name}.plist"
done
