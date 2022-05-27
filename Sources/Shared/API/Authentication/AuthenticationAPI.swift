import Alamofire
import Foundation
import ObjectMapper
import PromiseKit

typealias URLRequestConvertible = Alamofire.URLRequestConvertible

public class AuthenticationAPI {
    public enum AuthenticationError: LocalizedError {
        case serverError(statusCode: Int, errorCode: String?, error: String?)

        public var errorDescription: String? {
            switch self {
            case let .serverError(statusCode: statusCode, errorCode: errorCode, error: error):
                return [String(describing: statusCode), errorCode, error].compactMap { $0 }.joined(separator: ", ")
            }
        }
    }

    let server: Server
    let session: Session

    init(server: Server) {
        self.server = server
        self.session = Session(serverTrustManager: CustomServerTrustManager(server: server))
    }

    public func refreshTokenWith(tokenInfo: TokenInfo) -> Promise<TokenInfo> {
        Promise { seal in
            let token = tokenInfo.refreshToken
            let routeInfo = RouteInfo(
                route: AuthenticationRoute.refreshToken(token: token),
                baseURL: server.info.connection.activeURL()
            )
            let request = session.request(routeInfo)

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
                baseURL: server.info.connection.activeURL()
            )
            let request = session.request(routeInfo)

            request.validateAuth().response { _ in
                // https://developers.home-assistant.io/docs/en/auth_api.html#revoking-a-refresh-token says:
                //
                // The request will always respond with an empty body and HTTP status 200,
                // regardless if the request was successful.
                seal.fulfill(true)
            }
        }
    }

    public static func fetchToken(
        authorizationCode: String,
        baseURL: URL,
        exceptions: SecurityExceptions
    ) -> Promise<TokenInfo> {
        let session = Session(serverTrustManager: CustomServerTrustManager(exceptions: exceptions))

        return Promise { seal in
            let routeInfo = RouteInfo(
                route: AuthenticationRoute.token(authorizationCode: authorizationCode),
                baseURL: baseURL
            )
            let request = session.request(routeInfo)

            request.validateAuth().responseObject { (dataresponse: DataResponse<TokenInfo, AFError>) in
                switch dataresponse.result {
                case let .failure(error):
                    seal.reject(error)
                case let .success(value):
                    seal.fulfill(value)
                }
            }
        }.ensure {
            withExtendedLifetime(session) {
                // keeping session around until we're done
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
