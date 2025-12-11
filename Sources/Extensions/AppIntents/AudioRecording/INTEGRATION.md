# Integration Instructions

## Adding AudioRecordingAppIntent to the Xcode Project

The `AudioRecordingAppIntent.swift` file needs to be manually added to the Xcode project. Follow these steps:

### Step 1: Open the Project
1. Open `HomeAssistant.xcworkspace` in Xcode

### Step 2: Add Files to Project
1. In the Project Navigator (⌘1), navigate to `Sources/Extensions/AppIntents/`
2. Right-click on `AppIntents` folder
3. Select "Add Files to 'HomeAssistant'..."
4. Navigate to `Sources/Extensions/AppIntents/AudioRecording/`
5. Select both files:
   - `AudioRecordingAppIntent.swift`
   - `README.md`
6. Make sure "Copy items if needed" is **unchecked**
7. Make sure "Create groups" is selected
8. Select the appropriate targets (typically the main app target and any extension targets that use AppIntents)
9. Click "Add"

### Step 3: Verify File is Added
1. In Project Navigator, you should now see an `AudioRecording` folder under `AppIntents`
2. Click on the `AudioRecordingAppIntent.swift` file
3. In the File Inspector (⌘⌥1), verify that the correct targets are selected

### Step 4: Build the Project
1. Select the appropriate scheme (e.g., `App-Debug`)
2. Build the project (⌘B)
3. Verify there are no compilation errors

### Required Permissions

The AudioRecordingIntent requires microphone permissions. Ensure the following is in your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to your microphone to record audio.</string>
```

Also ensure the app has the appropriate Audio entitlements in the Capabilities tab of your target settings.

### Testing the Intent

Once integrated, you can test the intent through:

1. **Shortcuts App**: Create a new shortcut and search for "Record Audio"
2. **Siri**: Say "Hey Siri, record audio using Home Assistant"
3. **Code**: Call the intent programmatically using the AppIntents framework

### Troubleshooting

**Build Errors**: 
- Make sure all required frameworks are linked (AVFoundation, AppIntents)
- Verify the deployment target is iOS 17.0 or higher
- Check that the file is added to the correct targets

**Runtime Errors**:
- Verify microphone permissions are properly configured
- Check Console.app for log messages with the tag "AudioRecordingAppIntent"
- Ensure the device/simulator has microphone hardware available

### Logs

The intent logs all its operations using the `Current.Log` system. Look for logs prefixed with `AudioRecordingAppIntent:` to track:
- Recording start/stop
- Duration and parameters
- Permission status
- Recording metadata
- Error messages
