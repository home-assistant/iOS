import Alamofire
import Foundation
import ObjectMapper
import PromiseKit

typealias URLRequestConvertible = Alamofire.URLRequestConvertible

public enum ServerConnectionError: Error {
    case noActiveURL(_ serverName: String)
}

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
        #if !os(watchOS)
        // Use custom delegate that supports client certificates (mTLS)
        if server.info.connection.clientCertificate != nil {
            self.session = Session(
                delegate: ClientCertificateSessionDelegate(server: server),
                serverTrustManager: CustomServerTrustManager(server: server)
            )
        } else {
            self.session = Session(serverTrustManager: CustomServerTrustManager(server: server))
        }
        #else
        self.session = Session(serverTrustManager: CustomServerTrustManager(server: server))
        #endif
    }

    public func refreshTokenWith(tokenInfo: TokenInfo) -> Promise<TokenInfo> {
        Promise { seal in
            guard let activeUrl = server.info.connection.activeURL() else {
                seal.reject(ServerConnectionError.noActiveURL(server.info.name))
                return
            }
            let token = tokenInfo.refreshToken
            let routeInfo = RouteInfo(
                route: AuthenticationRoute.refreshToken(token: token),
                baseURL: activeUrl
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
            guard let activeUrl = server.info.connection.activeURL() else {
                seal.reject(ServerConnectionError.noActiveURL(server.info.name))
                return
            }
            let token = tokenInfo.accessToken
            let routeInfo = RouteInfo(
                route: AuthenticationRoute.revokeToken(token: token),
                baseURL: activeUrl
            )
            let request = session.request(routeInfo)

            request.validateAuth().response { _ in
                seal.fulfill(true)
            }
        }
    }

    public static func fetchToken(
        authorizationCode: String,
        baseURL: URL,
        exceptions: SecurityExceptions,
        clientCertificate: ClientCertificate? = nil
    ) -> Promise<TokenInfo> {
        let session: Session

        #if !os(watchOS)
        if let clientCert = clientCertificate {
            // Create a session delegate that handles client certificate challenges
            let delegate = OnboardingClientCertificateDelegate(certificate: clientCert)
            session = Session(
                delegate: delegate,
                serverTrustManager: CustomServerTrustManager(exceptions: exceptions)
            )
        } else {
            session = Session(serverTrustManager: CustomServerTrustManager(exceptions: exceptions))
        }
        #else
        session = Session(serverTrustManager: CustomServerTrustManager(exceptions: exceptions))
        #endif

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

#if !os(watchOS)
/// Session delegate for fetching initial token during onboarding (before server exists)
private class OnboardingClientCertificateDelegate: SessionDelegate {
    private let certificate: ClientCertificate

    init(certificate: ClientCertificate) {
        self.certificate = certificate
        super.init()
    }

    override func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            do {
                let credential = try ClientCertificateManager.shared.urlCredential(for: certificate)
                Current.Log.info("[mTLS] Using client certificate for token exchange: \(certificate.displayName)")
                completionHandler(.useCredential, credential)
                return
            } catch {
                Current.Log.error("[mTLS] Failed to get credential for token exchange: \(error)")
            }
        }

        super.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }
}
#endif

extension DataRequest {
    @discardableResult
    func validateAuth() -> Self {
        validate { _, response, data in
            if case 200 ..< 300 = response.statusCode {
                return .success(())
            } else if let data {
                let errorCode: String?
                let error: String?

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
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
