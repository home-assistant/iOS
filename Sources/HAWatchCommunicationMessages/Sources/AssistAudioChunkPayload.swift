import Foundation

/// Payload of an `assistAudioDataChunked` message (watch → phone): one 32 KB slice of a recording,
/// sent with ack-driven backpressure. Key names cross the wire — never rename them.
public struct AssistAudioChunkPayload {
    public let chunkData: Data
    public let chunkIndex: Int
    public let totalChunks: Int
    public let sampleRate: Double
    public let pipelineId: String
    public let serverId: String
    /// Unique per recording so the phone never mixes chunks of different attempts. Absent on watch
    /// builds that predate it (the phone then keys the upload by server + pipeline).
    public let recordingId: String?

    public init(
        chunkData: Data,
        chunkIndex: Int,
        totalChunks: Int,
        sampleRate: Double,
        pipelineId: String,
        serverId: String,
        recordingId: String? = nil
    ) {
        self.chunkData = chunkData
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.sampleRate = sampleRate
        self.pipelineId = pipelineId
        self.serverId = serverId
        self.recordingId = recordingId
    }

    public init?(content: [String: Any]) {
        guard let chunkData = content["chunkData"] as? Data,
              let chunkIndex = content["chunkIndex"] as? Int,
              let totalChunks = content["totalChunks"] as? Int,
              let sampleRate = content["sampleRate"] as? Double,
              let pipelineId = content["pipelineId"] as? String,
              let serverId = content["serverId"] as? String else {
            return nil
        }
        self.chunkData = chunkData
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.sampleRate = sampleRate
        self.pipelineId = pipelineId
        self.serverId = serverId
        self.recordingId = content["recordingId"] as? String
    }

    public var content: [String: Any] {
        var content: [String: Any] = [
            "chunkData": chunkData,
            "chunkIndex": chunkIndex,
            "totalChunks": totalChunks,
            "sampleRate": sampleRate,
            "pipelineId": pipelineId,
            "serverId": serverId,
        ]
        if let recordingId {
            content["recordingId"] = recordingId
        }
        return content
    }
}
