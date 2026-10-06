import Foundation

/// Payload of an `assistAudioStreamAck` reply (phone → watch), answering every message of an audio
/// stream. The watch sends the next chunk only once the previous one is acknowledged. Key names cross
/// the wire — never rename them.
public struct AssistAudioStreamAckPayload: Equatable {
    public let streamId: String
    /// Whether the phone still wants audio for this stream. `false` once speech has ended, the run
    /// is over or failed, or the stream is not one the phone knows, so the watch stops recording.
    public let isListening: Bool

    public init(streamId: String, isListening: Bool) {
        self.streamId = streamId
        self.isListening = isListening
    }

    public init?(content: [String: Any]) {
        guard let streamId = content["streamId"] as? String,
              let isListening = content["isListening"] as? Bool else {
            return nil
        }
        self.streamId = streamId
        self.isListening = isListening
    }

    public var content: [String: Any] {
        ["streamId": streamId, "isListening": isListening]
    }
}
