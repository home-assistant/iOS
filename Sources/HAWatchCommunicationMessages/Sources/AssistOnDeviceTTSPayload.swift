import Foundation

/// Payload of an `assistOnDeviceTTS` message (phone → watch): the answer the watch speaks with its
/// own speech synthesizer. Key names cross the wire, never rename them.
public struct AssistOnDeviceTTSPayload: Equatable {
    public let text: String
    public let voiceIdentifier: String?

    public init(text: String, voiceIdentifier: String? = nil) {
        self.text = text
        self.voiceIdentifier = voiceIdentifier
    }

    public init?(content: [String: Any]) {
        guard let text = content["text"] as? String else { return nil }
        self.text = text
        self.voiceIdentifier = content["voiceIdentifier"] as? String
    }

    public var content: [String: Any] {
        var content: [String: Any] = ["text": text]
        if let voiceIdentifier {
            content["voiceIdentifier"] = voiceIdentifier
        }
        return content
    }
}
