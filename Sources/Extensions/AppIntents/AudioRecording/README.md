# AudioRecordingAppIntent Sample

This is a sample implementation of Apple's `AudioRecordingIntent` protocol for the Home Assistant iOS app.

## Overview

`AudioRecordingAppIntent` demonstrates how to:
- Implement the `AudioRecordingIntent` protocol (iOS 17.0+)
- Record audio using AVFoundation
- Log audio input and metadata
- Handle microphone permissions
- Configure audio session parameters

## Features

- **Configurable Duration**: Set recording duration (1-60 seconds)
- **Metadata Logging**: Optional detailed logging of recording metadata
- **Error Handling**: Comprehensive error handling with descriptive messages
- **Permission Management**: Handles microphone access requests

## Usage

This intent can be triggered through:
- Siri Shortcuts
- Shortcuts app
- App Intents framework

### Parameters

- `duration` (Int): Recording duration in seconds (default: 10, range: 1-60)
- `logMetadata` (Bool): Whether to log detailed metadata (default: true)

### Logged Information

When `logMetadata` is enabled, the intent logs:
- Recording start/stop events
- File URL where audio is saved
- Recording duration
- Sample rate (Hz)
- Number of audio channels
- File size (bytes and KB)

## Technical Details

### Audio Settings

- **Format**: Linear PCM (WAV)
- **Sample Rate**: 44.1 kHz
- **Channels**: Stereo (2)
- **Bit Depth**: 16-bit
- **Quality**: High

### Temporary Storage

Audio files are saved to the system's temporary directory with a timestamp-based filename:
```
audio_recording_<timestamp>.wav
```

### Error Handling

The intent handles three main error cases:
- `invalidDuration`: Duration outside the 1-60 second range
- `microphoneAccessDenied`: User denied microphone permissions
- `recordingFailed`: Recording process failed with underlying error

## Requirements

- iOS 17.0+
- macOS 14.0+
- watchOS 10.0+
- Microphone permissions

## Integration

To use this intent in the app, it must be:
1. Added to the Xcode project targets that support App Intents
2. Included in the app's App Intents configuration
3. Properly code-signed with microphone permissions in the entitlements

## References

- [Apple AudioRecordingIntent Documentation](https://developer.apple.com/documentation/AppIntents/AudioRecordingIntent)
- [AVAudioRecorder Documentation](https://developer.apple.com/documentation/avfoundation/avaudiorecorder)
- [App Intents Documentation](https://developer.apple.com/documentation/appintents)
