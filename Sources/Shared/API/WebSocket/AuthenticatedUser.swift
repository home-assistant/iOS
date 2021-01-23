//
//  AuthenticatedUser.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/9/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation

public class AuthenticatedUser: Codable, CustomStringConvertible {
    public let ID: String
    public let Name: String
    public let IsOwner: Bool
    public let IsAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case ID = "id"
        case Name = "name"
        case IsOwner = "is_owner"
        case IsAdmin = "is_admin"
    }

    internal init(id: String, name: String, isOwner: Bool, isAdmin: Bool) {
        self.ID = id
        self.Name = name
        self.IsOwner = isOwner
        self.IsAdmin = isAdmin
    }

    public init?(_ dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String, let name = dictionary["name"] as? String else {
            return nil
        }
        self.ID = id
        self.Name = name
        self.IsOwner = dictionary["is_owner"] as? Bool ?? false
        self.IsAdmin = dictionary["is_admin"] as? Bool ?? false
    }

    public var description: String {
        return "AuthenticatedUser(id: \(self.ID), name: \(self.Name), owner: \(self.IsOwner), admin: \(self.IsAdmin)"
    }
}
