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
    public var Result: [String: Any]?
    public var Message: String?
    public var HAVersion: String?

    private enum CodingKeys: String, CodingKey {
        case MessageType = "type"
        case ID = "id"
        case Success = "success"
        case Result = "result"
        case Message = "message"
        case HAVersion = "ha_version"
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        MessageType = try values.decode(String.self, forKey: .MessageType)
        ID = try? values.decode(Int.self, forKey: .ID)
        Success = try? values.decode(Bool.self, forKey: .Success)
        Result = try? values.decode([String: Any].self, forKey: .Result)
        Message = try? values.decode(String.self, forKey: .Message)
        HAVersion = try? values.decode(String.self, forKey: .HAVersion)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(MessageType, forKey: .MessageType)
        if let ID = ID {
            try container.encode(ID, forKey: .ID)
        }
    }

    init(_ messageType: String) {
        self.MessageType = messageType
    }
}
