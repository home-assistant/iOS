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
    /// Whether an Apple Watch obtained this token by signing in to the server itself, rather than
    /// receiving a copy of the paired iPhone's token. A synced server snapshot never replaces a
    /// watch-issued token (see `ServerManagerImpl.restoreState`), so every watch keeps its own session
    /// that can be revoked on its own.
    public var isIssuedToWatch: Bool

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case expiration
        case refreshToken
        case isIssuedToWatch
    }

    public init(accessToken: String, refreshToken: String, expiration: Date, isIssuedToWatch: Bool = false) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiration = expiration
        self.isIssuedToWatch = isIssuedToWatch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.expiration = try container.decode(Date.self, forKey: .expiration)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        // Absent from tokens stored before watches could sign in on their own.
        self.isIssuedToWatch = try container.decodeIfPresent(Bool.self, forKey: .isIssuedToWatch) ?? false
    }

    public init(map: Map) throws {
        self.accessToken = try map.value("access_token")
        if let context = map.context as? TokenInfoContext {
            self.refreshToken = context.oldTokenInfo.refreshToken
            self.isIssuedToWatch = context.oldTokenInfo.isIssuedToWatch
        } else {
            self.refreshToken = try map.value("refresh_token")
            self.isIssuedToWatch = false
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
