import Foundation

/// Payload of an `assistOnDeviceTTS` message (phone → watch): the answer the watch speaks with its
/// own speech synthesizer. Key names cross the wire, never rename them.
public struct AssistOnDeviceTTSPayload: Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public init?(content: [String: Any]) {
        guard let text = content["text"] as? String else { return nil }
        self.text = text
    }

    public var content: [String: Any] {
        ["text": text]
    }
}
