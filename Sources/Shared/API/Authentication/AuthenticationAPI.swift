import Alamofire
import Foundation
import ObjectMapper
import PromiseKit

typealias URLRequestConvertible = Alamofire.URLRequestConvertible

public class AuthenticationAPI {
    public enum AuthenticationError: Error {
        case unexepectedType
        case unexpectedResponse
        case invalidCode
        case noConnectionInfo
    }

    private let forcedConnectionInfo: ConnectionInfo?

    init(forcedConnectionInfo: ConnectionInfo? = nil) {
        self.forcedConnectionInfo = forcedConnectionInfo
    }

    private func activeURL() throws -> URL {
        if let forcedConnectionInfo = forcedConnectionInfo {
            return forcedConnectionInfo.activeURL
        } else if let url = Current.settingsStore.connectionInfo?.activeURL {
            return url
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
            request.validate().responseObject(context: context) { (dataresponse: DataResponse<TokenInfo, AFError>) in
                switch dataresponse.result {
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

            request.validate().response { _ in
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

            request.validate().responseObject { (dataresponse: DataResponse<TokenInfo, AFError>) in
                switch dataresponse.result {
                case let .failure(networkError):

                    guard case let AFError.responseValidationFailed(reason: reason) = networkError,
                          case let AFError.ResponseValidationFailureReason.unacceptableStatusCode(code: code)
                          = reason, code == 400, let errorData = dataresponse.data else {
                        seal.reject(networkError)
                        return
                    }
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(
                            with: errorData,
                            options: .allowFragments
                        )
                        if let errorDictionary = jsonObject as? [String: AnyObject],
                           let errorString = errorDictionary["error_description"] as? String,
                           errorString == "Invalid code" {
                            seal.reject(AuthenticationError.invalidCode)
                            return
                        }
                    } catch {
                        Current.Log.error("Error deserializing failure json response: \(error)")
                    }
                case let .success(value):
                    seal.fulfill(value)
                }
            }
        }
    }
}
