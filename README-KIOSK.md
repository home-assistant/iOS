# Kiosk Mode for Home Assistant Companion

This document describes the Kiosk Mode features for dedicated Home Assistant display devices (wall panels, tablets, etc.).

## Features

### Display Control
- **Screensaver** - Clock, photos, dim, or blank screen after idle timeout
- **Wake on Motion** - Uses front camera to detect motion
- **Wake on Presence** - Uses front camera to detect people/faces
- **Wake on Touch** - Tap to wake from screensaver
- **Entity Triggers** - Wake/sleep based on HA entity states

### Dashboard
- **Default Dashboard** - Set which Lovelace dashboard to display
- **Dashboard Picker** - Select from available HA dashboards
- **Kiosk Mode URL** - Appends `?kiosk` for kiosk-mode HACS integration
- **Dashboard Rotation** - Cycle through multiple dashboards
- **Schedule-based Dashboards** - Show different dashboards by time/day

### Security
- **PIN Protection** - Require PIN to exit kiosk mode
- **Face ID / Touch ID** - Biometric authentication to exit
- **Navigation Lockdown** - Disable swipe gestures and pull-to-refresh
- **Status Bar Hidden** - Full-screen experience
- **Edge Protection** - Ignore accidental edge touches

### Camera Popup
- Picture-in-Picture camera overlay for doorbell/security events
- Action buttons: Talk, Unlock, Snapshot
- Auto-dismiss after timeout
- Draggable to screen corners

### Audio
- Text-to-Speech announcements
- Play audio files from URL
- Ambient sound detection (for voice commands)

## Notification Commands

Send commands to the device via HA notifications. Commands are executed silently (no banner shown).

### Simple Format
```yaml
service: notify.mobile_app_your_device
data:
  message: "command_refresh"
```

### Full Format (with parameters)
```yaml
service: notify.mobile_app_your_device
data:
  message: "Hidden message"
  data:
    homeassistant:
      command: "command_name"
      param1: "value1"
```

### Available Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `command_screen_on` | Wake screen | - |
| `command_screen_off` | Start screensaver | `mode` (optional) |
| `command_brightness` | Set brightness | `level` (0-100) |
| `command_screensaver` | Control screensaver | `action` (start/stop/toggle), `mode` |
| `command_navigate` | Navigate to URL | `path` or `url` |
| `command_refresh` | Reload page | - |
| `command_kiosk_mode` | Toggle kiosk | `enabled` (optional) |
| `command_tts` | Text-to-speech | `message`, `volume` (optional) |
| `command_play_audio` | Play audio | `url`, `volume` (optional) |
| `command_show_camera` | Show camera popup | See below |
| `command_dismiss_camera` | Hide camera popup | - |
| `command_launch_app` | Open app | `scheme`, `name` (optional) |
| `command_return` | Return to app | - |

### Camera Popup Command

```yaml
service: notify.mobile_app_your_device
data:
  message: "Doorbell Ring"
  data:
    homeassistant:
      command: "command_show_camera"
      entity_id: "camera.front_door"
      name: "Front Door"
      type: "doorbell"  # doorbell, security, generic
      show_actions: true
      unlock_entity_id: "lock.front_door"
      auto_dismiss: 30
```

## Example Automations

### Doorbell Camera Popup
```yaml
automation:
  - alias: "Show doorbell camera on ring"
    trigger:
      - platform: state
        entity_id: binary_sensor.doorbell_ring
        to: "on"
    action:
      - service: notify.mobile_app_kiosk_tablet
        data:
          message: "Doorbell"
          data:
            homeassistant:
              command: "command_show_camera"
              entity_id: "camera.doorbell"
              type: "doorbell"
              unlock_entity_id: "lock.front_door"
              auto_dismiss: 60
```

### Wake Display When Motion Detected
```yaml
automation:
  - alias: "Wake kiosk on motion"
    trigger:
      - platform: state
        entity_id: binary_sensor.hallway_motion
        to: "on"
    action:
      - service: notify.mobile_app_kiosk_tablet
        data:
          message: "command_screen_on"
```

### Navigate to Security Dashboard
```yaml
automation:
  - alias: "Show cameras when alarm triggered"
    trigger:
      - platform: state
        entity_id: alarm_control_panel.home
        to: "triggered"
    action:
      - service: notify.mobile_app_kiosk_tablet
        data:
          message: "Alarm Triggered"
          data:
            homeassistant:
              command: "command_navigate"
              path: "/lovelace/security"
```

### TTS Announcement
```yaml
automation:
  - alias: "Announce visitor"
    trigger:
      - platform: state
        entity_id: binary_sensor.doorbell_ring
        to: "on"
    action:
      - service: notify.mobile_app_kiosk_tablet
        data:
          message: "TTS"
          data:
            homeassistant:
              command: "command_tts"
              message: "Someone is at the front door"
```

## Settings

Access Kiosk Mode settings in the app:
**Settings > Kiosk Mode**

### Core Settings
- Enable/Disable Kiosk Mode
- Exit PIN
- Allow Face ID/Touch ID
- Lock Navigation
- Hide Status Bar

### Dashboard
- Default Dashboard (picker from HA)
- Kiosk Mode URL toggle
- Dashboard Rotation

### Screensaver
- Idle Timeout
- Mode (Clock, Photos, Dim, Blank, Custom URL)
- Clock Format (12hr/24hr)
- Pixel Shift (burn-in prevention)

### Camera & Presence
- Camera Motion Detection
- Person Detection
- Wake on Motion/Presence
- Report to Home Assistant (sensors)

## Sensors

When enabled, the app reports these sensors to Home Assistant:

- `sensor.device_kiosk_screen_state` - on/screensaver/off
- `sensor.device_kiosk_mode` - enabled/disabled
- `binary_sensor.device_camera_motion` - motion detected
- `binary_sensor.device_camera_presence` - person detected

## Blueprints

Pre-built blueprints are available in your HA config at `blueprints/automation/kiosk/`:

| Blueprint | Description |
|-----------|-------------|
| `doorbell_camera_popup.yaml` | Show camera popup on doorbell ring |
| `wake_on_motion.yaml` | Wake display on motion detection |
| `screen_control.yaml` | Control screen based on entity states |
| `dashboard_switcher.yaml` | Switch dashboards based on triggers |
| `tts_announcement.yaml` | Play TTS announcements |

To use: Go to **Settings > Automations > Blueprints** in Home Assistant.

## Requirements

- iOS 15.0+
- Home Assistant 2023.1+
- Mobile App integration configured
- For Local Push: Internal URL and SSIDs configured
