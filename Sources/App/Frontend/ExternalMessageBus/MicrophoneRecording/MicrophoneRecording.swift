import AVFoundation
import Foundation

/// A finished recording, as the frontend receives it in the `microphone/recording/stop` result.
struct MicrophoneRecording: Equatable {
    static let mimeType = "audio/wav"

    let sessionId: String
    let audio: Data
    let sampleRate: Double
    let channels: Int
    let duration: TimeInterval

    var payload: [String: Any] {
        [
            "session_id": sessionId,
            "audio": audio.base64EncodedString(),
            "mime_type": Self.mimeType,
            "sample_rate": Int(sampleRate),
            "channels": channels,
            "duration": duration,
        ]
    }
}

extension MicrophoneRecording {
    init(sessionId: String, fileURL: URL) throws {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.fileFormat
        self.init(
            sessionId: sessionId,
            audio: try Data(contentsOf: fileURL),
            sampleRate: format.sampleRate,
            channels: Int(format.channelCount),
            duration: format.sampleRate > 0 ? Double(file.length) / format.sampleRate : 0
        )
    }
}
