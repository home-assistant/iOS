# Kiosk Mode Feature

This document describes the Kiosk Mode feature for dedicated Home Assistant display devices.

---

## Overview

Kiosk Mode transforms iOS devices into dedicated wall-mounted displays for Home Assistant. It provides screen management, navigation lockdown, and remote control capabilities through notification commands.

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

## Files Added

### New Kiosk Files
```
Sources/App/Kiosk/
├── KioskModeManager.swift
├── KioskSettings.swift
├── KioskConstants.swift
├── Settings/
│   ├── KioskSettingsView.swift
│   ├── ScreensaverConfigView.swift
│   ├── DashboardConfigurationView.swift
│   └── EntityTriggersView.swift
├── Screensaver/
│   ├── ScreensaverViewController.swift
│   ├── ClockScreensaverView.swift
│   ├── PhotoScreensaverView.swift
│   ├── CustomURLScreensaverView.swift
│   ├── PhotoManager.swift
│   └── EntityStateProvider.swift
├── Camera/
│   ├── CameraOverlayView.swift
│   ├── CameraDetectionManager.swift
│   ├── CameraStreamViewController.swift
│   ├── CameraMotionDetector.swift
│   └── PresenceDetector.swift
├── Overlay/
│   ├── StatusOverlayView.swift
│   ├── EdgeProtectionView.swift
│   ├── SecretExitGestureView.swift
│   └── QuickActionsView.swift
├── Commands/
│   └── KioskCommandHandlers.swift
├── Audio/
│   ├── AudioManager.swift
│   └── AmbientAudioDetector.swift
├── AppLauncher/
│   ├── AppLauncherManager.swift
│   └── QuickLaunchPanelView.swift
├── Dashboard/
│   └── DashboardManager.swift
├── Triggers/
│   └── EntityTriggerManager.swift
├── Security/
│   ├── SecurityManager.swift
│   ├── SettingsManager.swift
│   ├── TamperDetectionManager.swift
│   ├── GuidedAccessManager.swift
│   ├── BatteryManager.swift
│   └── CrashRecoveryManager.swift
└── Utilities/
    ├── IconMapper.swift
    ├── TouchFeedbackManager.swift
    └── AnimationUtilities.swift
```

### Modified Files
- `Sources/App/WebView/WebViewController.swift` - Kiosk mode integration
- `Sources/App/WebView/Extensions/WebViewController+Kiosk.swift` - Kiosk extensions
- `Sources/App/Notifications/NotificationManager.swift` - Command handling
- `Sources/Shared/Notifications/LocalPush/LocalPushManager.swift` - Reconnection
- `Sources/Shared/Notifications/NotificationCommands/NotificationsCommandManager.swift` - Command parsing
