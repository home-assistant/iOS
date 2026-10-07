import Foundation

/// Payload of an `assistAudioChunkAck` reply (phone → watch): acknowledges one audio chunk so the
/// watch sends the next. Key names cross the wire — never rename them.
public struct AssistAudioChunkAckPayload {
    public let acknowledged: Bool
    public let chunkIndex: Int
    public let totalChunks: Int

    public init(acknowledged: Bool = true, chunkIndex: Int, totalChunks: Int) {
        self.acknowledged = acknowledged
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
    }

    public init?(content: [String: Any]) {
        guard let acknowledged = content["acknowledged"] as? Bool,
              let chunkIndex = content["chunkIndex"] as? Int,
              let totalChunks = content["totalChunks"] as? Int else {
            return nil
        }
        self.acknowledged = acknowledged
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
    }

    public var content: [String: Any] {
        [
            "acknowledged": acknowledged,
            "chunkIndex": chunkIndex,
            "totalChunks": totalChunks,
        ]
    }
}
