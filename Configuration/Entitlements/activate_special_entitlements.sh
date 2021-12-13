#!/bin/bash

ENTITLEMENTS_FILE="${TARGET_TEMP_DIR}/${FULL_PRODUCT_NAME}.xcent"

if [[ $CI && $CONFIGURATION != "Release" ]]; then
  echo "warning: Critical alerts disabled for CI"
elif [[ ${ENABLE_CRITICAL_ALERTS} -eq 1 ]]; then
    /usr/libexec/PlistBuddy -c "add com.apple.developer.usernotifications.critical-alerts bool true" "$ENTITLEMENTS_FILE"
else
    echo "warning: Critical alerts disabled"
fi

if [[ $CI && $CONFIGURATION != "Release" ]]; then
  echo "warning: Push provider disabled for CI"
elif [[ ${ENABLE_PUSH_PROVIDER} -eq 1 ]]; then
    /usr/libexec/PlistBuddy -c "add com.apple.developer.networking.networkextension array" "$ENTITLEMENTS_FILE"
    /usr/libexec/PlistBuddy -c "add com.apple.developer.networking.networkextension:0 string 'app-push-provider'" "$ENTITLEMENTS_FILE"
else
    echo "warning: Push provider disabled"
fi
