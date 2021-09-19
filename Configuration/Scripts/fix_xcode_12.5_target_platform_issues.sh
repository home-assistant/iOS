#!/bin/bash

# when building for iOS, Xcode expects the Launcher.app to exist
LAUNCHER_INFO_PLIST_PATH=$BUILD_DIR/Debug/Home\ Assistant\ Launcher.app/Contents/Info.plist
if [ ! -f "$LAUNCHER_INFO_PLIST_PATH" ]; then
	mkdir -p "$(dirname "$LAUNCHER_INFO_PLIST_PATH")"

	cat >"$LAUNCHER_INFO_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>io.robbie.HomeAssistant.dev.Launcher</string>
</dict>
</plist>
EOF
fi

WATCHAPP_INFO_PLIST_PATH=$BUILD_DIR/Debug-watchos/HomeAssistant-WatchApp.app/Info.plist
if [ ! -f "$WATCHAPP_INFO_PLIST_PATH" ]; then
	mkdir -p "$(dirname "$WATCHAPP_INFO_PLIST_PATH")"

	cat >"$WATCHAPP_INFO_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>io.robbie.HomeAssistant.dev.watchkitapp</string>
</dict>
</plist>
EOF
fi
