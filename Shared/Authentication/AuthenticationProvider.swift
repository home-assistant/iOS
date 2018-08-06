//
//  AuthorizationProvider.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public struct AuthenticationProvider: ImmutableMappable {
    public let id: String?
    public let type: String
    public let name: String

    public init(map: Map) throws {
        self.id = try? map.value("id")
        self.type = try map.value("type")
        self.name = try map.value("name")
    }
}
