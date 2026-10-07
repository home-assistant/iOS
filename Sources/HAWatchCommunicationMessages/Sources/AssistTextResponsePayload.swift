import Foundation

/// Payload of `assistSTTResponse` and `assistIntentEndResponse` messages (phone → watch): the
/// transcribed input or the pipeline's final answer. Key names cross the wire — never rename them.
public struct AssistTextResponsePayload {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public init?(content: [String: Any]) {
        guard let text = content["content"] as? String else { return nil }
        self.text = text
    }

    public var content: [String: Any] {
        ["content": text]
    }
}
