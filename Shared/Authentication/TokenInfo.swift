//
//  TokenInfo.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/20/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public struct TokenInfo: ImmutableMappable, Codable {
    struct TokenInfoContext: MapContext {
        var oldTokenInfo: TokenInfo
    }

    let accessToken: String
    let expiration: Date
    let refreshToken: String

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

    /// Returns true if the current access token needs refreshing.
    public var needsRefresh: Bool {
        return expiration < Current.date()
    }
}
