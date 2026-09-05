import Foundation

/// Payload of an `assistAudioStreamChunkAck` reply (phone → watch): acknowledges one live audio
/// chunk and says whether the pipeline still wants more. Key names cross the wire — never rename
/// them.
public struct AssistAudioStreamChunkAckPayload {
    public let chunkIndex: Int
    /// `false` once the pipeline stopped taking audio — its voice-activity detection ended the
    /// command, speech-to-text finished, or the run failed. The watch stops recording on the first
    /// `false`.
    public let keepListening: Bool

    public init(chunkIndex: Int, keepListening: Bool) {
        self.chunkIndex = chunkIndex
        self.keepListening = keepListening
    }

    public init?(content: [String: Any]) {
        guard let chunkIndex = content["chunkIndex"] as? Int,
              let keepListening = content["keepListening"] as? Bool else {
            return nil
        }
        self.chunkIndex = chunkIndex
        self.keepListening = keepListening
    }

    public var content: [String: Any] {
        [
            "chunkIndex": chunkIndex,
            "keepListening": keepListening,
        ]
    }
}
