//
//  TokenInfo.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/20/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import Alamofire

public struct TokenInfo: ImmutableMappable, Codable {
    struct TokenInfoContext: MapContext {
        var oldTokenInfo: TokenInfo
    }

    let accessToken: String
    let expiration: Date
    let refreshToken: String

    public init(accessToken: String, refreshToken: String, expiration: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiration = expiration
    }

    public init(map: Map) throws {
        self.accessToken = try map.value("access_token")
        if let context = map.context as? TokenInfoContext {
            self.refreshToken = context.oldTokenInfo.refreshToken
        } else {
            self.refreshToken = try map.value("refresh_token")
        }

        let ttlInSeconds: Int = try map.value("expires_in")
        self.expiration = Date(timeIntervalSinceNow: TimeInterval(ttlInSeconds))
    }
}

extension TokenInfo: AuthenticationCredential {
    public var requiresRefresh: Bool {
        expiration.addingTimeInterval(-60) < Current.date()
    }
}
