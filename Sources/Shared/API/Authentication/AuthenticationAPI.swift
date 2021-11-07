import Alamofire
import Foundation
import ObjectMapper
import PromiseKit

typealias URLRequestConvertible = Alamofire.URLRequestConvertible

public class AuthenticationAPI {
    public enum AuthenticationError: LocalizedError {
        case noConnectionInfo
        case serverError(statusCode: Int, errorCode: String?, error: String?)

        public var errorDescription: String? {
            switch self {
            case .noConnectionInfo: return L10n.HaApi.ApiError.notConfigured
            case let .serverError(statusCode: statusCode, errorCode: errorCode, error: error):
                return [String(describing: statusCode), errorCode, error].compactMap { $0 }.joined(separator: ", ")
            }
        }
    }

    private let connectionInfoGetter: () -> ConnectionInfo?

    init(forcedConnectionInfo: ConnectionInfo) {
        self.connectionInfoGetter = { forcedConnectionInfo }
    }

    init(server: Server) {
        self.connectionInfoGetter = { server.info.connection }
    }

    private func activeURL() throws -> URL {
        if let connectionInfo = connectionInfoGetter() {
            return connectionInfo.activeURL
        } else {
            throw AuthenticationError.noConnectionInfo
        }
    }

    public func refreshTokenWith(tokenInfo: TokenInfo) -> Promise<TokenInfo> {
        Promise { seal in
            let token = tokenInfo.refreshToken
            let routeInfo = RouteInfo(
                route: AuthenticationRoute.refreshToken(token: token),
                baseURL: try activeURL()
            )
            let request = Session.default.request(routeInfo)

            let context = TokenInfo.TokenInfoContext(oldTokenInfo: tokenInfo)
            request.validateAuth().responseObject(context: context) { (response: DataResponse<TokenInfo, AFError>) in
                switch response.result {
                case let .failure(error):
                    seal.reject(error)
                case let .success(value):
                    seal.fulfill(value)
                }
            }
        }
    }

    public func revokeToken(tokenInfo: TokenInfo) -> Promise<Bool> {
        Promise { seal in
            let token = tokenInfo.accessToken
            let routeInfo = RouteInfo(
                route: AuthenticationRoute.revokeToken(token: token),
                baseURL: try activeURL()
            )
            let request = Session.default.request(routeInfo)

            request.validateAuth().response { _ in
                // https://developers.home-assistant.io/docs/en/auth_api.html#revoking-a-refresh-token says:
                //
                // The request will always respond with an empty body and HTTP status 200,
                // regardless if the request was successful.
                seal.fulfill(true)
            }
        }
    }

    public func fetchTokenWithCode(_ authorizationCode: String) -> Promise<TokenInfo> {
        Promise { seal in
            let routeInfo = RouteInfo(
                route: AuthenticationRoute.token(authorizationCode: authorizationCode),
                baseURL: try activeURL()
            )
            let request = Session.default.request(routeInfo)

            request.validateAuth().responseObject { (dataresponse: DataResponse<TokenInfo, AFError>) in
                switch dataresponse.result {
                case let .failure(error):
                    seal.reject(error)
                case let .success(value):
                    seal.fulfill(value)
                }
            }
        }
    }
}

extension DataRequest {
    @discardableResult
    func validateAuth() -> Self {
        validate { _, response, data in
            if case 200 ..< 300 = response.statusCode {
                return .success(())
            } else if let data = data {
                let errorCode: String?
                let error: String?

                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    errorCode = json["error"] as? String
                    error = json["error_description"] as? String
                } else {
                    errorCode = nil
                    error = String(data: data, encoding: .utf8)
                }

                return .failure(AuthenticationAPI.AuthenticationError.serverError(
                    statusCode: response.statusCode,
                    errorCode: errorCode,
                    error: error
                ))
            } else {
                return .failure(AFError.responseValidationFailed(
                    reason: .unacceptableStatusCode(code: response.statusCode)
                ))
            }
        }
    }
}
