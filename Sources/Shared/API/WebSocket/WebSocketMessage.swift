import Foundation

public class WebSocketMessage: Codable {
    public let MessageType: String
    public var ID: Int?
    public var Success: Bool?
    public var Payload: [String: Any]?
    public var Result: [String: Any]?
    public var Message: String?
    public var HAVersion: String?
    public var command: String?
    public var error: ResultError?

    private enum CodingKeys: String, CodingKey {
        case MessageType = "type"
        case ID = "id"
        case Success = "success"
        case Payload = "payload"
        case Result = "result"
        case Message = "message"
        case HAVersion = "ha_version"
        case command = "command"
        case error = "error"
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.MessageType = try values.decode(String.self, forKey: .MessageType)
        self.ID = try? values.decode(Int.self, forKey: .ID)
        self.Success = try? values.decode(Bool.self, forKey: .Success)
        self.Payload = try? values.decode([String: Any].self, forKey: .Payload)
        self.Result = try? values.decode([String: Any].self, forKey: .Result)
        self.Message = try? values.decode(String.self, forKey: .Message)
        self.HAVersion = try? values.decode(String.self, forKey: .HAVersion)
        self.command = try values.decodeIfPresent(String.self, forKey: .command)
    }

    public init?(_ dictionary: [String: Any]) {
        guard let mType = dictionary["type"] as? String else {
            return nil
        }
        self.MessageType = mType
        self.ID = dictionary["id"] as? Int
        self.Payload = dictionary["payload"] as? [String: Any]
        self.Result = dictionary["result"] as? [String: Any]
        self.Success = dictionary["success"] as? Bool
        self.command = dictionary["command"] as? String
    }

    public init(_ incomingMessage: WebSocketMessage, _ result: [String: Any]) {
        self.ID = incomingMessage.ID
        self.MessageType = "result"
        self.Result = result
        self.Success = true
        self.command = nil
    }

    public init(id: Int, type: String, result: [String: Any], success: Bool = true) {
        self.ID = id
        self.MessageType = type
        self.Result = result
        self.Success = success
        self.command = nil
    }

    /// The frontend branches on `code` and shows its own text.
    public struct ResultError: Codable, Equatable {
        private static let canceledCode = "canceled"
        private static let failedCode = "failed"

        public let code: String
        /// English detail for the app's log, never shown to the user.
        public let message: String

        public static func canceled(_ message: String) -> Self {
            .init(code: canceledCode, message: message)
        }

        public static func failed(_ message: String) -> Self {
            .init(code: failedCode, message: message)
        }

        public var isCanceled: Bool {
            code == Self.canceledCode
        }
    }

    public init(id: Int, error: ResultError) {
        self.ID = id
        self.MessageType = "result"
        self.Success = false
        self.error = error
        self.command = nil
    }

    public init(id: Int = -1, command: String, payload: [String: Any]? = nil) {
        self.ID = id
        self.MessageType = "command"
        self.command = command
        self.Payload = payload
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(MessageType, forKey: .MessageType)
        if let ID {
            try container.encode(ID, forKey: .ID)
        }
        if let Success {
            try container.encode(Success, forKey: .Success)
        }
        if let Message {
            try container.encode(Message, forKey: .Message)
        }
        if let Result {
            try container.encode(Result, forKey: .Result)
        }
        if let Payload {
            try container.encode(Payload, forKey: .Payload)
        }
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(error, forKey: .error)
    }

    init(_ messageType: String) {
        self.MessageType = messageType
    }
}

extension WebSocketMessage: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "WebSocketMessage(type: \(MessageType), id: \(String(describing: ID)), payload: \(String(describing: Payload)), result: \(String(describing: Result)), success: \(String(describing: Success)), error: \(String(describing: error)))"
    }

    public var debugDescription: String {
        description
    }
}
