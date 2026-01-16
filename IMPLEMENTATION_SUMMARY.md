# CallKit Notification Command Implementation Summary

## Overview
This implementation adds a new notification command `call_assist` that uses Apple's CallKit framework to present an incoming call UI on iOS devices. When the user answers the call, the Home Assistant Assist interface opens automatically.

## Files Changed

### New Files Created

1. **`Sources/Shared/Notifications/CallKit/CallKitManager.swift`**
   - Core CallKit integration manager
   - Handles incoming call presentation using CXProvider
   - Thread-safe state management with DispatchQueue
   - Delegates call answer events to NotificationManager
   - Automatically ends the call after answer

2. **`Documentation/CallKitAssistCommand.md`**
   - Comprehensive documentation for the new command
   - Usage examples with various parameter combinations
   - Implementation notes and limitations

3. **Test Case Files**
   - `Sources/PushServer/Tests/SharedPushTests/notification_test_cases.bundle/command_call_assist.json`
   - `Sources/PushServer/Tests/SharedPushTests/notification_test_cases.bundle/command_call_assist_with_params.json`

### Modified Files

1. **`Sources/Shared/Notifications/NotificationCommands/NotificationsCommandManager.swift`**
   - Added new `HandlerCallAssist` command handler
   - Registered `call_assist` command in iOS-only section
   - Extracts optional parameters: `caller_name`, `pipeline_id`, `auto_start_recording`
   - Triggers CallKit incoming call when command is received

2. **`Sources/App/Notifications/NotificationManager.swift`**
   - Implements `CallKitManagerDelegate` protocol
   - Sets up CallKit delegate in initialization
   - Opens AssistView when call is answered
   - Proper error handling for missing servers and promise failures

## Key Features

### Thread Safety
- All CallKit state operations are protected with a dedicated DispatchQueue
- Atomic `captureAndClearState()` method ensures race-free state transitions
- Separate computed properties for thread-safe get/set operations

### Error Handling
- Guard statement prevents crash when no servers are available
- Promise error handling with explicit logging
- CallKit API error handling with detailed logging

### Parameters
The command supports the following optional parameters:
- `caller_name`: The name displayed on the incoming call screen (default: "Home Assistant")
- `pipeline_id`: The ID of a specific Assist pipeline to use (default: "")
- `auto_start_recording`: Whether to automatically start voice recording (default: false)

## Usage Example

```yaml
service: notify.mobile_app_iphone
data:
  message: "command"
  data:
    command: call_assist
    caller_name: "Front Door Camera"
    auto_start_recording: true
```

## Technical Implementation Details

### CallKit Integration
1. Creates a CXProvider with configuration for generic calls
2. Reports incoming call with customizable caller name
3. Handles CXAnswerCallAction to detect when user answers
4. Immediately ends the call after answer (it's just a trigger)
5. Supports CallKit delegate methods for proper lifecycle management

### State Management
- Uses private `_activeCallInfo` and `_activeCallUUID` for internal state
- Provides thread-safe public accessors via computed properties
- Atomic operations for capturing and clearing state prevent race conditions

### Notification Flow
1. Home Assistant sends push notification with `call_assist` command
2. NotificationCommandManager receives and parses the command
3. HandlerCallAssist extracts parameters and calls CallKitManager
4. CallKitManager presents native iOS incoming call UI
5. User answers the call
6. CallKitManagerDelegate (NotificationManager) is notified
7. AssistView is opened with specified parameters
8. Call is automatically ended

## Code Quality

### Code Review Issues Addressed
✅ Thread safety with DispatchQueue and atomic operations
✅ Race condition prevention in state management
✅ Proper error handling throughout the call chain
✅ No force unwrapping of optionals
✅ Clean separation of concerns

### Testing
- Test case JSON files added for notification parser
- Can be manually tested by sending push notifications from Home Assistant

## Future Enhancements

Potential improvements for future iterations:
1. Support for server selection from notification payload
2. Custom call sounds or vibration patterns
3. CallKit call history integration
4. Support for multiple concurrent calls (if needed)
5. Localization of caller name strings

## Compatibility

- **Platform**: iOS only (uses CallKit framework)
- **Minimum iOS Version**: iOS 10.0+ (CallKit availability)
- **Works on**: Lock screen, home screen, and when app is in background
- **Requires**: Remote notifications enabled
- **Similar to**: `update_widgets` command (background notification command pattern)

## Security Considerations

- No actual call is placed - this is purely a UI trigger
- Uses existing Home Assistant authentication and server connection
- CallKit does not require additional permissions beyond notifications
- State is cleared immediately after use to prevent reuse
- Thread-safe implementation prevents data races

## Documentation

Complete documentation is available in `Documentation/CallKitAssistCommand.md` with:
- Overview and use cases
- Complete parameter reference
- Multiple usage examples
- Implementation notes
- Testing instructions
