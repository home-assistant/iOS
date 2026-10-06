import Alamofire
import Foundation

struct RouteInfo: Alamofire.URLRequestConvertible {
    let route: AuthenticationRoute
    let baseURL: URL

    func asURLRequest() throws -> URLRequest {
        try route.asURLRequestWith(baseURL: baseURL)
    }
}

enum AuthenticationRoute {
    case token(authorizationCode: String)
    case refreshToken(token: String)
    case revokeToken(token: String)

    func asURLRequestWith(baseURL: URL) throws -> URLRequest {
        let baseRequest = try URLRequest(url: baseURL.appendingPathComponent(path), method: method)
        let request: URLRequest
        if let parameters {
            request = try URLEncoding.httpBody.encode(baseRequest, with: parameters)
        } else {
            request = baseRequest
        }
        return request
    }

    // MARK: - Private helpers

    static var clientID: String {
        var clientID = "https://home-assistant.io/iOS"

        // swiftlint:disable prohibit_environment_assignment
        if HANetworkingEnvironment.current.isDebug {
            clientID = "https://home-assistant.io/iOS/dev-auth"
        }
        // swiftlint:enable prohibit_environment_assignment

        return clientID
    }

    /// The redirect URI registered for `clientID`, which the login flow validates even when no browser
    /// follows it.
    static var redirectURI: String {
        HANetworkingEnvironment.current.isDebug ? "homeassistant-dev://auth-callback" : "homeassistant://auth-callback"
    }

    private var clientID: String { Self.clientID }

    private var method: HTTPMethod {
        .post
    }

    private var parameters: Parameters? {
        switch self {
        case let .token(authorizationCode):
            return ["client_id": clientID, "grant_type": "authorization_code", "code": authorizationCode]
        case let .refreshToken(token):
            return ["client_id": clientID, "grant_type": "refresh_token", "refresh_token": token]
        case let .revokeToken(token):
            return ["action": "revoke", "token": token]
        }
    }

    private var path: String {
        switch self {
        case .token:
            return "auth/token"
        case .refreshToken:
            return "auth/token"
        case .revokeToken:
            return "auth/token"
        }
    }
}
