import Foundation

/// Why the app ended a recording without the frontend stopping it, sent as `reason` in
/// `microphone/recording/stopped`.
enum MicrophoneRecordingStopReason: String {
    /// The app went to the background.
    case background
    /// The system took the microphone, for a call or Siri.
    case interrupted
    /// The recording reached `MicrophoneRecordingSession.maximumDuration`.
    case maxDuration = "max_duration"
    /// The frontend started another recording.
    case replaced
    /// The recorder stopped with an error.
    case failed
}
