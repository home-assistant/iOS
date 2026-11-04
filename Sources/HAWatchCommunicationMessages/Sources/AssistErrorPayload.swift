import Foundation

/// Payload of an `assistError` message (phone → watch): a stable code plus a human-readable
/// message shown in the watch's assist chat. Key names cross the wire — never rename them.
public struct AssistErrorPayload {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    public init?(content: [String: Any]) {
        guard let code = content["code"] as? String,
              let message = content["message"] as? String else {
            return nil
        }
        self.code = code
        self.message = message
    }

    public var content: [String: Any] {
        ["code": code, "message": message]
    }
}
