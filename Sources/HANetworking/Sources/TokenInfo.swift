import Alamofire
import Foundation
import ObjectMapper

public struct TokenInfo: ImmutableMappable, Codable, Equatable {
    public struct TokenInfoContext: MapContext {
        public var oldTokenInfo: TokenInfo
        public init(oldTokenInfo: TokenInfo) {
            self.oldTokenInfo = oldTokenInfo
        }
    }

    public var accessToken: String
    public var expiration: Date
    public var refreshToken: String

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

    public static func == (lhs: TokenInfo, rhs: TokenInfo) -> Bool {
        lhs.refreshToken == rhs.refreshToken
            && lhs.accessToken == rhs.accessToken
    }
}

extension TokenInfo: AuthenticationCredential {
    public var requiresRefresh: Bool {
        expiration.addingTimeInterval(-60) < HANetworkingEnvironment.current.date()
    }
}
