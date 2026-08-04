import Foundation

/// Payload of an `assistTextInput` message (watch → phone): the written prompt to run through an
/// Assist pipeline. Key names cross the wire — never rename them.
public struct AssistTextInputPayload {
    public let text: String
    public let pipelineId: String
    public let serverId: String

    public init(text: String, pipelineId: String, serverId: String) {
        self.text = text
        self.pipelineId = pipelineId
        self.serverId = serverId
    }

    public init?(content: [String: Any]) {
        guard let text = content["text"] as? String,
              let pipelineId = content["pipelineId"] as? String,
              let serverId = content["serverId"] as? String else {
            return nil
        }
        self.text = text
        self.pipelineId = pipelineId
        self.serverId = serverId
    }

    public var content: [String: Any] {
        [
            "text": text,
            "pipelineId": pipelineId,
            "serverId": serverId,
        ]
    }
}
