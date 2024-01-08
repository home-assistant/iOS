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

if [[ $TARGET_NAME = "App" ]]; then
    if [[ $CI && $CONFIGURATION != "Release" ]]; then
      echo "warning: THREAD_NETWORK_CREDENTIALS disabled for CI"
    elif [[ ${ENABLE_THREAD_NETWORK_CREDENTIALS} -eq 1 ]]; then
        /usr/libexec/PlistBuddy -c "add com.apple.developer.networking.manage-thread-network-credentials bool true" "$ENTITLEMENTS_FILE"
    else
        echo "warning: THREAD_NETWORK_CREDENTIALS disabled"
    fi
fi

if [[ $TARGET_NAME = "App" ]]; then
  if [[ $CI && $CONFIGURATION != "Release" ]]; then
    echo "warning: com.apple.developer.carplay-driving-task disabled for CI"
  elif [[ ${ENABLE_CARPLAY} -eq 1 ]]; then
      /usr/libexec/PlistBuddy -c "add com.apple.developer.carplay-driving-task bool true" "$ENTITLEMENTS_FILE"
  else
      echo "warning: com.apple.developer.carplay-driving-task entitlement disabled"
  fi
fi


if [[ $TARGET_NAME = "App" ]]; then
  if [[ $CI && $CONFIGURATION != "Release" ]]; then
    echo "warning: Device name disabled for CI"
  elif [[ ${ENABLE_DEVICE_NAME} -eq 1 ]]; then
      /usr/libexec/PlistBuddy -c "add com.apple.developer.device-information.user-assigned-device-name bool true" "$ENTITLEMENTS_FILE"
  else
      echo "warning: Device name disabled"
  fi
fi
