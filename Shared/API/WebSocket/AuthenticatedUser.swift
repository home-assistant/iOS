//
//  AuthenticatedUser.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/9/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation

public class AuthenticatedUser: Codable {
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

    init(_ dictionary: [String: Any]) {
        self.ID = dictionary["id"] as? String ?? "Unknown"
        self.Name = dictionary["name"] as? String ?? "Unknown"
        self.IsOwner = dictionary["is_owner"] as? Bool ?? false
        self.IsAdmin = dictionary["is_admin"] as? Bool ?? false
    }
}
