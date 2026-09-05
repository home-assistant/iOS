import Foundation

/// Payload of an `assistAudioStreamChunk` message (watch → phone): the PCM audio captured since the
/// previous chunk of a recording still in progress. Key names cross the wire — never rename them.
public struct AssistAudioStreamChunkPayload {
    /// Unique per recording: the first chunk of a new id starts a pipeline run, and the phone never
    /// mixes chunks of different recordings.
    public let recordingId: String
    /// Position of the chunk within the recording, starting at 0. Chunks are sent one at a time,
    /// each only after the previous one was acknowledged, so the index is for logging rather than
    /// reordering.
    public let chunkIndex: Int
    /// Little-endian 16-bit mono PCM at `sampleRate`.
    public let chunkData: Data
    public let sampleRate: Double
    public let pipelineId: String
    public let serverId: String

    public init(
        recordingId: String,
        chunkIndex: Int,
        chunkData: Data,
        sampleRate: Double,
        pipelineId: String,
        serverId: String
    ) {
        self.recordingId = recordingId
        self.chunkIndex = chunkIndex
        self.chunkData = chunkData
        self.sampleRate = sampleRate
        self.pipelineId = pipelineId
        self.serverId = serverId
    }

    public init?(content: [String: Any]) {
        guard let recordingId = content["recordingId"] as? String,
              let chunkIndex = content["chunkIndex"] as? Int,
              let chunkData = content["chunkData"] as? Data,
              let sampleRate = content["sampleRate"] as? Double,
              let pipelineId = content["pipelineId"] as? String,
              let serverId = content["serverId"] as? String else {
            return nil
        }
        self.recordingId = recordingId
        self.chunkIndex = chunkIndex
        self.chunkData = chunkData
        self.sampleRate = sampleRate
        self.pipelineId = pipelineId
        self.serverId = serverId
    }

    public var content: [String: Any] {
        [
            "recordingId": recordingId,
            "chunkIndex": chunkIndex,
            "chunkData": chunkData,
            "sampleRate": sampleRate,
            "pipelineId": pipelineId,
            "serverId": serverId,
        ]
    }
}
