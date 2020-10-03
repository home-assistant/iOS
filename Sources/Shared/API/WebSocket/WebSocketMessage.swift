//
//  WebSocketMessage.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/9/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation

public class WebSocketMessage: Codable {
    public let MessageType: String
    public var ID: Int?
    public var Success: Bool?
    public var Payload: [String: Any]?
    public var Result: [String: Any]?
    public var Message: String?
    public var HAVersion: String?

    private enum CodingKeys: String, CodingKey {
        case MessageType = "type"
        case ID = "id"
        case Success = "success"
        case Payload = "payload"
        case Result = "result"
        case Message = "message"
        case HAVersion = "ha_version"
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        MessageType = try values.decode(String.self, forKey: .MessageType)
        ID = try? values.decode(Int.self, forKey: .ID)
        Success = try? values.decode(Bool.self, forKey: .Success)
        Payload = try? values.decode([String: Any].self, forKey: .Payload)
        Result = try? values.decode([String: Any].self, forKey: .Result)
        Message = try? values.decode(String.self, forKey: .Message)
        HAVersion = try? values.decode(String.self, forKey: .HAVersion)
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
    }

    public init(_ incomingMessage: WebSocketMessage, _ result: [String: Any]) {
        self.ID = incomingMessage.ID
        self.MessageType = "result"
        self.Result = result
        self.Success = true
    }

    public init(id: Int, type: String, result: [String: Any], success: Bool = true) {
        self.ID = id
        self.MessageType = type
        self.Result = result
        self.Success = success
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(MessageType, forKey: .MessageType)
        if let ID = ID {
            try container.encode(ID, forKey: .ID)
        }
        if let Success = Success {
            try container.encode(Success, forKey: .Success)
        }
        if let Message = Message {
            try container.encode(Message, forKey: .Message)
        }
        if let Result = Result {
            try container.encode(Result, forKey: .Result)
        }
    }

    init(_ messageType: String) {
        self.MessageType = messageType
    }
}

extension WebSocketMessage: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        // swiftlint:disable:next line_length
        return "WebSocketMessage(type: \(self.MessageType), id: \(String(describing: self.ID)), payload: \(String(describing: self.Payload)), result: \(String(describing: self.Result)), success: \(String(describing: self.Success)))"
    }

    public var debugDescription: String {
        return self.description
    }
}
