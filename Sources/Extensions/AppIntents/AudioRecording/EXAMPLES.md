# AudioRecordingAppIntent Usage Examples

This document provides examples of how to use the `AudioRecordingAppIntent` in different contexts.

## Example 1: Using in Shortcuts App

The intent can be used directly in the Shortcuts app:

1. Open the Shortcuts app
2. Create a new shortcut
3. Tap "Add Action"
4. Search for "Record Audio" or "Home Assistant"
5. Select the "Record Audio" action
6. Configure parameters:
   - Recording Duration: Set between 1-60 seconds
   - Log Metadata: Toggle on/off

## Example 2: Programmatic Usage

```swift
import AppIntents

@available(iOS 17.0, *)
func recordAudioExample() async throws {
    // Create the intent with custom parameters
    let intent = AudioRecordingAppIntent()
    intent.duration = 15 // 15 seconds
    intent.logMetadata = true
    
    // Perform the intent
    let result = try await intent.perform()
    let response = result.value
    
    // Access the recording information
    print("Recording saved to: \(response.fileURL)")
    print("Duration: \(response.duration) seconds")
    print("Sample rate: \(response.sampleRate) Hz")
    print("Channels: \(response.channels)")
    print("File size: \(response.fileSize) bytes")
}
```

## Example 3: Integration with Siri

Users can invoke the intent through Siri:

```
"Hey Siri, record audio using Home Assistant"
"Hey Siri, record audio for 5 seconds"
"Hey Siri, use Home Assistant to record audio"
```

Siri will:
1. Request microphone permission (if not already granted)
2. Start recording with the configured duration
3. Save the recording and log metadata
4. Provide feedback to the user

## Example 4: Automations with Shortcuts

Combine with other actions to create powerful automations:

### Morning Voice Note
```
1. AudioRecordingAppIntent (duration: 30 seconds)
2. Save to Files (in specific folder)
3. Send notification with file link
```

### Quick Voice Memo with Home Assistant
```
1. AudioRecordingAppIntent (duration: 60 seconds, log: true)
2. Upload to cloud storage
3. Create task/reminder with audio attachment
```

### Security Monitoring
```
When: Motion detected
Then:
1. Turn on lights (Home Assistant action)
2. AudioRecordingAppIntent (duration: 10 seconds)
3. Send recording to notification
```

## Example 5: Checking Logs

After running the intent, check the logs:

```swift
// In your app's console or using Console.app, filter for:
// "AudioRecordingAppIntent"

// You'll see logs like:
AudioRecordingAppIntent: Starting audio recording
AudioRecordingAppIntent: Duration: 10 seconds
AudioRecordingAppIntent: Log metadata: true
AudioRecordingAppIntent: Microphone access granted
AudioRecordingAppIntent: Audio session configured
AudioRecordingAppIntent: Recording to file: /tmp/audio_recording_1234567890.wav
AudioRecordingAppIntent: Starting recording...
AudioRecordingAppIntent: Recording stopped
AudioRecordingAppIntent: Recording Metadata:
  - File URL: /tmp/audio_recording_1234567890.wav
  - Duration: 10.0 seconds
  - Sample Rate: 44100.0 Hz
  - Channels: 2
  - File Size: 1764044 bytes (1722.7 KB)
AudioRecordingAppIntent: Recording completed successfully
```

## Example 6: Error Handling

```swift
import AppIntents

@available(iOS 17.0, *)
func recordAudioWithErrorHandling() async {
    let intent = AudioRecordingAppIntent()
    intent.duration = 5
    
    do {
        let result = try await intent.perform()
        print("Recording successful!")
        print("File: \(result.value.fileURL)")
    } catch AudioRecordingError.invalidDuration {
        print("Error: Invalid duration specified")
    } catch AudioRecordingError.microphoneAccessDenied {
        print("Error: Microphone access was denied")
    } catch AudioRecordingError.recordingFailed(let message) {
        print("Error: Recording failed - \(message)")
    } catch {
        print("Error: Unexpected error - \(error)")
    }
}
```

## Example 7: Custom Integration in SwiftUI

```swift
import SwiftUI
import AppIntents

@available(iOS 17.0, *)
struct AudioRecordingView: View {
    @State private var isRecording = false
    @State private var recordingURL: URL?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Record Audio") {
                Task {
                    await recordAudio()
                }
            }
            .disabled(isRecording)
            
            if isRecording {
                ProgressView("Recording...")
            }
            
            if let url = recordingURL {
                Text("Recording saved to: \(url.lastPathComponent)")
                    .font(.caption)
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
    
    func recordAudio() async {
        isRecording = true
        errorMessage = nil
        recordingURL = nil
        
        let intent = AudioRecordingAppIntent()
        intent.duration = 10
        intent.logMetadata = true
        
        do {
            let result = try await intent.perform()
            recordingURL = result.value.fileURL
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRecording = false
    }
}
```

## Testing Tips

1. **Simulator Testing**: The intent works in the iOS Simulator, but audio quality may vary
2. **Device Testing**: For best results, test on a physical device
3. **Permission Testing**: Reset microphone permissions in Settings > Privacy > Microphone to test permission flow
4. **Log Monitoring**: Use Console.app or Xcode console to see detailed logs
5. **File Verification**: Check the temporary directory to verify files are created

## Notes

- Recorded files are saved to the temporary directory and may be cleaned up by the system
- Consider implementing a file management strategy if recordings need to be persisted
- Audio format is optimized for speech recognition (Linear PCM, 44.1kHz)
- The intent enforces a maximum duration of 60 seconds to prevent excessive storage use
