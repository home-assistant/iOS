import Foundation

/// Payload of the messages that end an audio stream early, naming the stream they end:
/// `assistAudioStreamCancel` (watch → phone) drops the recording, and `assistAudioStreamStop`
/// (phone → watch) says the phone stopped listening. Key names cross the wire — never rename them.
public struct AssistAudioStreamEndPayload: Equatable {
    public let streamId: String

    public init(streamId: String) {
        self.streamId = streamId
    }

    public init?(content: [String: Any]) {
        guard let streamId = content["streamId"] as? String else { return nil }
        self.streamId = streamId
    }

    public var content: [String: Any] {
        ["streamId": streamId]
    }
}
