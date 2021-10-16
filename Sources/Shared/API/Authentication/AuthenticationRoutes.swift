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
        if let parameters = parameters {
            request = try URLEncoding.httpBody.encode(baseRequest, with: parameters)
        } else {
            request = baseRequest
        }
        return request
    }

    // MARK: - Private helpers

    private var clientID: String {
        var clientID = "https://home-assistant.io/iOS"

        if Current.appConfiguration == .Debug {
            clientID = "https://home-assistant.io/iOS/dev-auth"
        } else if Current.appConfiguration == .Beta {
            clientID = "https://home-assistant.io/iOS/beta-auth"
        }
        return clientID
    }

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
