# CallKit Assist Notification Command

This document describes the `call_assist` notification command that uses CallKit to present an incoming call UI and opens AssistView when answered.

## Overview

The `call_assist` command triggers a CallKit incoming call notification on iOS devices. When the user answers the call, the Home Assistant Assist interface opens automatically.

## Use Case

This command is useful for:
- Quickly accessing voice assistant from lock screen
- Responding to urgent home automation needs
- Hands-free interaction with Home Assistant

## Command Format

```yaml
service: notify.mobile_app_<your_device_id_here>
data:
  message: "command"
  data:
    command: call_assist
    # Optional parameters:
    caller_name: "Home Assistant"  # The name shown for the incoming call
    pipeline_id: ""                # Specific Assist pipeline to use
    auto_start_recording: false    # Start recording automatically when opened
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `command` | string | Yes | - | Must be `call_assist` |
| `caller_name` | string | No | "Home Assistant" | The name displayed on the incoming call screen |
| `pipeline_id` | string | No | "" | The ID of a specific Assist pipeline to use |
| `auto_start_recording` | boolean | No | false | Whether to automatically start voice recording when Assist opens |

## Examples

### Basic Usage

```yaml
service: notify.mobile_app_iphone
data:
  message: "command"
  data:
    command: call_assist
```

### With Custom Caller Name

```yaml
service: notify.mobile_app_iphone
data:
  message: "command"
  data:
    command: call_assist
    caller_name: "Kitchen Motion Detected"
```

### With Auto-Recording

```yaml
service: notify.mobile_app_iphone
data:
  message: "command"
  data:
    command: call_assist
    caller_name: "Front Door"
    auto_start_recording: true
```

### With Specific Pipeline

```yaml
service: notify.mobile_app_iphone
data:
  message: "command"
  data:
    command: call_assist
    caller_name: "Smart Assistant"
    pipeline_id: "01ARZ3NDEKTSV4RRFFQ69G5FAV"
    auto_start_recording: true
```

## Implementation Notes

- This command is only available on iOS (not watchOS or macOS)
- The call will automatically end once answered, as it's only used to trigger the Assist interface
- The command uses Apple's CallKit framework for native call integration
- This works even when the device is locked (subject to device settings)
- No actual call is placed - this is purely a UI trigger mechanism

## Testing

To test this command, send a notification with the above format from Home Assistant. When you answer the incoming call on your iOS device, the Assist interface will open automatically.
