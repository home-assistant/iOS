import Foundation

/// Payload of an `assistAudioStreamStart` message (watch → phone): a recording is starting, and its
/// audio follows in `assistAudioStreamChunk` messages while the user is still speaking. The audio is
/// 16-bit mono PCM at `sampleRate`. Key names cross the wire — never rename them.
public struct AssistAudioStreamStartPayload: Equatable {
    /// Unique per recording, so the phone never mixes the audio of one recording into another.
    public let streamId: String
    public let sampleRate: Double
    public let pipelineId: String
    public let serverId: String

    public init(streamId: String, sampleRate: Double, pipelineId: String, serverId: String) {
        self.streamId = streamId
        self.sampleRate = sampleRate
        self.pipelineId = pipelineId
        self.serverId = serverId
    }

    public init?(content: [String: Any]) {
        guard let streamId = content["streamId"] as? String,
              let sampleRate = content["sampleRate"] as? Double,
              let pipelineId = content["pipelineId"] as? String,
              let serverId = content["serverId"] as? String else {
            return nil
        }
        self.streamId = streamId
        self.sampleRate = sampleRate
        self.pipelineId = pipelineId
        self.serverId = serverId
    }

    public var content: [String: Any] {
        [
            "streamId": streamId,
            "sampleRate": sampleRate,
            "pipelineId": pipelineId,
            "serverId": serverId,
        ]
    }
}
