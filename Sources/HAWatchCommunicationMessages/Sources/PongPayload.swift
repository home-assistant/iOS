import Foundation

/// Payload of a `pong` reply (phone → watch): the Assist messages the phone could not push to the
/// watch on their own, in the order they were produced. Key names cross the wire — never rename them.
public struct PongPayload {
    public let assistMessages: [(identifier: String, content: [String: Any])]

    public init(assistMessages: [(identifier: String, content: [String: Any])] = []) {
        self.assistMessages = assistMessages
    }

    public init(content: [String: Any]) {
        let entries = content["assistMessages"] as? [[String: Any]] ?? []
        self.assistMessages = entries.compactMap { entry in
            guard let identifier = entry["identifier"] as? String,
                  let content = entry["content"] as? [String: Any] else {
                return nil
            }
            return (identifier: identifier, content: content)
        }
    }

    public var content: [String: Any] {
        guard !assistMessages.isEmpty else { return [:] }
        return ["assistMessages": assistMessages.map { ["identifier": $0.identifier, "content": $0.content] }]
    }
}
