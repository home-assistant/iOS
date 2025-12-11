import AppIntents
import AVFoundation
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct AudioRecordingAppIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.audio_recording.title",
        defaultValue: "Record Audio"
    )

    static let description = IntentDescription(
        .init(
            "app_intents.audio_recording.description",
            defaultValue: "Records audio and logs the input"
        )
    )

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.audio_recording.duration.title",
            defaultValue: "Recording Duration (seconds)"
        ),
        description: LocalizedStringResource(
            "app_intents.audio_recording.duration.description",
            defaultValue: "Maximum duration for the audio recording in seconds"
        ),
        default: 10
    )
    var duration: Int

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.audio_recording.log_metadata.title",
            defaultValue: "Log Metadata"
        ),
        description: LocalizedStringResource(
            "app_intents.audio_recording.log_metadata.description",
            defaultValue: "Log detailed metadata about the recording"
        ),
        default: true
    )
    var logMetadata: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Record audio for \(\.$duration) seconds") {
            \.$logMetadata
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<AudioRecordingAppIntentResponse> {
        Current.Log.info("AudioRecordingAppIntent: Starting audio recording")

        // Log intent parameters
        Current.Log.info("AudioRecordingAppIntent: Duration: \(duration) seconds")
        Current.Log.info("AudioRecordingAppIntent: Log metadata: \(logMetadata)")

        // Validate duration
        guard duration > 0, duration <= 60 else {
            Current.Log.error("AudioRecordingAppIntent: Invalid duration \(duration), must be between 1-60 seconds")
            throw AudioRecordingError.invalidDuration
        }

        // Request microphone access
        let microphoneAccess = await AVAudioApplication.requestRecordPermission()
        guard microphoneAccess else {
            Current.Log.error("AudioRecordingAppIntent: Microphone access denied")
            throw AudioRecordingError.microphoneAccessDenied
        }
        Current.Log.info("AudioRecordingAppIntent: Microphone access granted")

        // Perform audio recording
        let response = try await recordAudio(duration: duration)

        // Log metadata if requested
        if logMetadata {
            logRecordingMetadata(response)
        }

        Current.Log.info("AudioRecordingAppIntent: Recording completed successfully")
        return .result(value: response)
    }

    private func recordAudio(duration: Int) async throws -> AudioRecordingAppIntentResponse {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Configure audio session
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            Current.Log.info("AudioRecordingAppIntent: Audio session configured")

            // Create temporary file for recording
            let fileURL = createTemporaryAudioFileURL()
            Current.Log.info("AudioRecordingAppIntent: Recording to file: \(fileURL.path)")

            // Configure recording settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]

            // Create and start recorder
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()

            Current.Log.info("AudioRecordingAppIntent: Starting recording...")
            recorder.record()

            // Record for specified duration
            try await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000_000)

            // Stop recording
            recorder.stop()
            Current.Log.info("AudioRecordingAppIntent: Recording stopped")

            // Deactivate audio session
            try audioSession.setActive(false)

            // Get file attributes
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            return AudioRecordingAppIntentResponse(
                fileURL: fileURL,
                duration: Double(duration),
                sampleRate: recorder.format.sampleRate,
                channels: Int(recorder.format.channelCount),
                fileSize: fileSize
            )
        } catch {
            Current.Log.error("AudioRecordingAppIntent: Recording failed with error: \(error.localizedDescription)")
            try? audioSession.setActive(false)
            throw AudioRecordingError.recordingFailed(error.localizedDescription)
        }
    }

    private func createTemporaryAudioFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "audio_recording_\(Date().timeIntervalSince1970).wav"
        return tempDir.appendingPathComponent(fileName)
    }

    private func logRecordingMetadata(_ response: AudioRecordingAppIntentResponse) {
        Current.Log.info("AudioRecordingAppIntent: Recording Metadata:")
        Current.Log.info("  - File URL: \(response.fileURL.path)")
        Current.Log.info("  - Duration: \(response.duration) seconds")
        Current.Log.info("  - Sample Rate: \(response.sampleRate) Hz")
        Current.Log.info("  - Channels: \(response.channels)")
        Current.Log.info("  - File Size: \(response.fileSize) bytes (\(Double(response.fileSize) / 1024.0) KB)")
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct AudioRecordingAppIntentResponse: Codable, Sendable {
    let fileURL: URL
    let duration: Double
    let sampleRate: Double
    let channels: Int
    let fileSize: Int64
}

enum AudioRecordingError: LocalizedError {
    case invalidDuration
    case microphoneAccessDenied
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Invalid recording duration. Must be between 1-60 seconds."
        case .microphoneAccessDenied:
            return "Microphone access is required to record audio."
        case let .recordingFailed(message):
            return "Audio recording failed: \(message)"
        }
    }
}
