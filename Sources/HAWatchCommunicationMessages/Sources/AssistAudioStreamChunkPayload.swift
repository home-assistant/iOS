import Foundation

/// Payload of an `assistAudioStreamChunk` message (watch → phone): the audio recorded since the
/// previous chunk of a stream. Key names cross the wire — never rename them.
public struct AssistAudioStreamChunkPayload: Equatable {
    public let streamId: String
    /// Position of this chunk in its stream, from 0.
    public let sequence: Int
    public let audio: Data
    /// The user submitted the recording: no audio follows this chunk.
    public let isFinal: Bool

    public init(streamId: String, sequence: Int, audio: Data, isFinal: Bool) {
        self.streamId = streamId
        self.sequence = sequence
        self.audio = audio
        self.isFinal = isFinal
    }

    public init?(content: [String: Any]) {
        guard let streamId = content["streamId"] as? String,
              let sequence = content["sequence"] as? Int,
              let audio = content["audio"] as? Data,
              let isFinal = content["isFinal"] as? Bool else {
            return nil
        }
        self.streamId = streamId
        self.sequence = sequence
        self.audio = audio
        self.isFinal = isFinal
    }

    public var content: [String: Any] {
        [
            "streamId": streamId,
            "sequence": sequence,
            "audio": audio,
            "isFinal": isFinal,
        ]
    }
}
