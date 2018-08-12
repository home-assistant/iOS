//
//  TokenInfo.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/20/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public struct TokenInfo: ImmutableMappable {
    let accessToken: String
    let expiration: Date
    let refreshToken: String

    public init(map: Map) throws {
        self.accessToken = try map.value("access_token")
        self.refreshToken = try map.value("refresh_token")
        let ttlInSeconds: Int = try map.value("expires_in")
        self.expiration = Date(timeIntervalSinceNow: TimeInterval(ttlInSeconds))
    }
}
