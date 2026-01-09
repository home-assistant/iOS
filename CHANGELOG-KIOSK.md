# Kiosk Mode Changelog

This document tracks changes specific to Kiosk Mode that diverge from the upstream Home Assistant iOS app.

**Base:** Home Assistant Companion iOS (imported, no direct git lineage)
**Upstream:** https://github.com/home-assistant/iOS

---

## App Identity Changes

These changes differentiate Kiosk Mode from the official HA app for testing purposes:

- **App Name:** Changed to "Home Assistant Δ" (delta symbol indicates fork)
- **Bundle ID:** `com.kiosk-mode.HomeAssistant`
- **Signing Team:** KG2Y5YM34S

---

## Notification Handling Changes

- **Direct WebSocket Local Push:** Removed PushProvider Network Extension (requires Apple entitlement). Uses `NotificationManagerLocalPushInterfaceDirect` for WebSocket-based local push when app is in foreground.
- **Command Notifications:** Added support for `command_*` notifications that execute silently (no banner)
- **WebSocket Reconnection:** Added automatic reconnection when app returns to foreground after device sleep

---

## Kiosk Mode Features

### Core Infrastructure
- `KioskModeManager` - Central coordinator for kiosk mode state
- `KioskSettings` - Persistent settings with app group UserDefaults
- Navigation lockdown (disable swipe gestures, pull-to-refresh)
- Status bar hiding

### Screensaver System
- Multiple modes: Clock, Clock with Entities, Photos, Photos with Clock, Dim, Blank
- Idle timer with configurable timeout
- Day/night brightness schedule
- Photo slideshow from HA media source
- Pixel shift to prevent burn-in
- 12/24-hour clock format option

### Screen Wake Features
- Wake on motion detection (Vision framework)
- Wake on presence detection (person standing in front)
- Presence activity timer (keeps screen awake while presence detected)
- Wake on camera entity state change

### Camera Popup System
- `command_show_camera` / `command_dismiss_camera` commands
- PiP-style overlay with configurable size and position
- MJPEG streaming with HA authentication
- Doorbell actions (talk, unlock, snapshot)
- Custom action buttons
- Alert sounds (doorbell, motion, urgent)
- Auto-dismiss timer

### Dashboard Management
- Dashboard rotation with configurable intervals
- Dashboard picker (fetches available dashboards from HA)
- Kiosk mode URL toggle (appends `?kiosk` for kiosk-mode HACS)
- Entity-triggered dashboard switching

### Secret Exit Gesture
- Configurable multi-tap in corner to access settings
- PIN or FaceID/TouchID authentication
- Device passcode fallback option

### Quick Launch Panel
- Slide-out panel for app shortcuts
- URL scheme-based app launching
- Configurable gesture trigger

### Notification Commands (14 total)
| Command | Description |
|---------|-------------|
| `command_screen_on` | Wake screen |
| `command_screen_off` | Start screensaver |
| `command_brightness` | Set brightness level |
| `command_screensaver` | Control screensaver |
| `command_navigate` | Navigate to URL/path |
| `command_refresh` | Reload current page |
| `command_kiosk_mode` | Toggle kiosk mode |
| `command_volume` | Set volume |
| `command_tts` | Text-to-speech |
| `command_play_audio` | Play audio file |
| `command_launch_app` | Launch app by URL scheme |
| `command_return` | Return to app |
| `command_show_camera` | Show camera popup |
| `command_dismiss_camera` | Dismiss camera popup |

---

## Bug Fixes (Kiosk Mode-specific)

- Fixed camera popup touch handling (UIKit/SwiftUI passthrough)
- Fixed settings persistence across app updates (app group migration)
- Fixed double PIN prompt when exiting kiosk mode
- Fixed FaceID authentication flow when no PIN set
- Fixed screensaver triggering while user standing in front
- Fixed camera motion/person detection not waking from screensaver

---

## Files Added/Modified

### New Kiosk Files
```
Sources/App/Kiosk/
├── KioskModeManager.swift
├── Settings/
│   ├── KioskSettings.swift
│   ├── KioskSettingsView.swift
│   └── ScreensaverConfigView.swift
├── Screensaver/
│   ├── ScreensaverViewController.swift
│   ├── ClockScreensaverView.swift
│   ├── PhotoScreensaverView.swift
│   └── CustomURLScreensaverView.swift
├── Camera/
│   ├── CameraOverlayView.swift
│   ├── CameraDetectionManager.swift
│   └── CameraTakeoverManager.swift
├── Overlay/
│   ├── StatusOverlayView.swift
│   ├── EdgeProtectionView.swift
│   └── SecretExitGestureView.swift
├── Commands/
│   └── KioskCommandHandlers.swift
├── Audio/
│   ├── AudioManager.swift
│   └── AmbientAudioDetector.swift
├── AppLauncher/
│   ├── AppLauncherManager.swift
│   └── QuickLaunchPanelView.swift
└── Dashboard/
    ├── DashboardManager.swift
    └── EntityTriggerManager.swift
```

### Modified Files
- `Sources/App/WebView/WebViewController.swift` - Kiosk mode integration
- `Sources/App/WebView/Extensions/WebViewController+Kiosk.swift` - Kiosk extensions
- `Sources/App/Notifications/NotificationManager.swift` - Command handling
- `Sources/Shared/Notifications/LocalPush/LocalPushManager.swift` - Reconnection
- Various notification interfaces for WebSocket reconnection

---

## Syncing with Upstream

To pull upstream changes:
```bash
git fetch upstream
git merge upstream/main
# Resolve conflicts, especially in notification handling
```

**High-conflict areas:**
- `NotificationManager.swift`
- `LocalPushManager.swift`
- Project configuration files

---

## Related Repositories

| Repository | Purpose |
|------------|---------|
| [Home Assistant iOS Fork](https://github.com/nstefanelli/ha-kiosk) | iOS app (this repo) |
| [Kiosk Mode Integration](https://github.com/nstefanelli/haframe-integration) | HA custom component + blueprints |
