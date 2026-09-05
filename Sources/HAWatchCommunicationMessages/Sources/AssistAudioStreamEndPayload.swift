import Foundation

/// Payload of an `assistAudioStreamEnd` message (watch → phone) and its `assistAudioStreamEndAck`
/// reply: the recording ended on the watch. Key names cross the wire — never rename them.
public struct AssistAudioStreamEndPayload {
    public let recordingId: String

    public init(recordingId: String) {
        self.recordingId = recordingId
    }

    public init?(content: [String: Any]) {
        guard let recordingId = content["recordingId"] as? String else { return nil }
        self.recordingId = recordingId
    }

    public var content: [String: Any] {
        ["recordingId": recordingId]
    }
}
