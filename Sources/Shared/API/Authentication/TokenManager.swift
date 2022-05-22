import Alamofire
import Foundation
import PromiseKit

public class TokenManager {
    public enum TokenError: Error {
        case tokenUnavailable
        case expired
        case connectionFailed
    }

    public let server: Server
    private var authenticationAPI: AuthenticationAPI

    private class RefreshPromiseCache {
        // we can be asked to refresh from any queue - alamofire's utility queue, webview's main queue, so guard
        // accessing the underlying promise here without being on the queue is programmer error
        let queue: DispatchQueue
        private let queueSpecific = DispatchSpecificKey<Bool>()

        init() {
            self.queue = DispatchQueue(label: "refresh-promise-cache-mutex", qos: .userInitiated)
            queue.setSpecific(key: queueSpecific, value: true)
        }

        private var underlyingPromise: Promise<TokenInfo>?

        var promise: Promise<TokenInfo>? {
            get {
                assert(DispatchQueue.getSpecific(key: queueSpecific) == true)
                return underlyingPromise
            }
            set {
                assert(DispatchQueue.getSpecific(key: queueSpecific) == true)
                underlyingPromise = newValue
            }
        }
    }

    private let refreshPromiseCache = RefreshPromiseCache()

    public init(server: Server) {
        self.authenticationAPI = AuthenticationAPI(server: server)
        self.server = server
    }

    /// After authenticating with the server and getting a code, call this method to exchange the code for
    /// an auth token.
    /// - Parameter code: Code acquired by authenticating with an authenticaiton provider.
    public static func initialToken(
        code: String,
        connectionInfo: inout ConnectionInfo
    ) -> Promise<TokenInfo> {
        AuthenticationAPI.fetchToken(
            authorizationCode: code,
            baseURL: connectionInfo.activeURL(),
            exceptions: connectionInfo.securityExceptions
        )
    }

    // Request the server revokes the current token.
    public func revokeToken() -> Promise<Bool> {
        authenticationAPI.revokeToken(tokenInfo: server.info.token)
    }

    public var bearerToken: Promise<(String, Date)> {
        firstly {
            self.currentToken
        }.recover { [self] error -> Promise<(String, Date)> in
            guard let tokenError = error as? TokenError, tokenError == TokenError.expired else {
                Current.Log.verbose("Unable to recover from token error! \(error)")
                throw error
            }

            return refreshToken().map {
                Current.Log.info("providing token \($0.accessToken.hash)")
                return ($0.accessToken, $0.expiration)
            }
        }
    }

    public func authDictionaryForWebView(forceRefresh: Bool) -> Promise<[String: Any]> {
        firstly { () -> Promise<(String, Date)> in
            if forceRefresh {
                Current.Log.info("forcing a refresh of token")
                return refreshToken().map { ($0.accessToken, $0.expiration) }
            } else {
                Current.Log.info("using existing token")
                return bearerToken
            }
        }.map { token, expiration -> [String: Any] in
            Current.Log.info("creating webview token with \(token.hash)")
            var dictionary: [String: Any] = [:]
            dictionary["access_token"] = token
            dictionary["expires_in"] = Int(expiration.timeIntervalSince(Current.date()))
            return dictionary
        }
    }

    // MARK: - Private helpers

    private var currentToken: Promise<(String, Date)> {
        Promise<(String, Date)> { seal in
            let tokenInfo = server.info.token

            // Add a margin to -10 seconds so that we never get into a state where we return a token
            // that immediately fails.
            if tokenInfo.expiration.addingTimeInterval(-10) > Current.date() {
                seal.fulfill((tokenInfo.accessToken, tokenInfo.expiration))
            } else {
                if let expirationAmount = Calendar.current.dateComponents(
                    [.second],
                    from: tokenInfo.expiration,
                    to: Current.date()
                ).second {
                    Current.Log.error("Token \(tokenInfo.accessToken.hash) is expired by \(expirationAmount) seconds")
                } else {
                    Current.Log.error("Token \(tokenInfo.accessToken.hash) is expired by unknown")
                }

                seal.reject(TokenError.expired)
            }
        }
    }

    private func refreshToken() -> Promise<TokenInfo> {
        refreshPromiseCache.queue.sync { [self, server] in
            let tokenInfo = server.info.token

            if let refreshPromise = self.refreshPromiseCache.promise {
                Current.Log.info("using cached refreshToken promise")
                return refreshPromise
            }

            let promise: Promise<TokenInfo> = firstly {
                authenticationAPI.refreshTokenWith(tokenInfo: tokenInfo)
            }.get { [server] tokenInfo in
                Current.Log.info("storing refresh token")
                server.info.token = tokenInfo
            }.ensure(on: refreshPromiseCache.queue) { [self] in
                Current.Log.info("reset cached refreshToken promise")
                refreshPromiseCache.promise = nil
            }.tap { [server] result in
                switch result {
                case let .rejected(error):
                    Current.Log.error("refresh token got error: \(error)")

                    if let underlying = (error as? AFError)?.underlyingError as? AuthenticationAPI.AuthenticationError,
                       case .serverError(400 ... 403, _, _) = underlying {
                        /// Server rejected the refresh token. All is lost.
                        let event = ClientEvent(
                            text: "Refresh token is invalid, showing onboarding",
                            type: .networkRequest,
                            payload: [
                                "error": String(describing: underlying),
                            ]
                        )
                        Current.clientEventStore.addEvent(event).cauterize()

                        Current.servers.remove(identifier: server.identifier)
                        Current.onboardingObservation.needed(.error)
                    }
                case .fulfilled:
                    Current.Log.info("refresh token got success")
                }
            }

            Current.Log.info("starting refreshToken cache")
            refreshPromiseCache.promise = promise
            return promise
        }
    }
}

extension TokenManager.TokenError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .tokenUnavailable:
            return L10n.TokenError.tokenUnavailable
        case .expired:
            return L10n.TokenError.expired
        case .connectionFailed:
            return L10n.TokenError.connectionFailed
        }
    }
}

extension TokenManager: Authenticator {
    public var authenticationInterceptor: AuthenticationInterceptor<TokenManager> {
        AuthenticationInterceptor(authenticator: self, credential: server.info.token, refreshWindow: nil)
    }

    public func apply(_ credential: TokenInfo, to urlRequest: inout URLRequest) {
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
    }

    public func refresh(
        _ credential: TokenInfo,
        for session: Session,
        completion: @escaping (Swift.Result<TokenInfo, Error>) -> Void
    ) {
        firstly {
            refreshToken()
        }.done { token in
            completion(.success(token))
        }.catch { error in
            completion(.failure(error))
        }
    }

    public func didRequest(
        _ urlRequest: URLRequest,
        with response: HTTPURLResponse,
        failDueToAuthenticationError error: Error
    ) -> Bool {
        switch response.statusCode {
        case 401:
            return true
        default:
            return false
        }
    }

    public func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: TokenInfo) -> Bool {
        let bearerToken = HTTPHeader.authorization(bearerToken: credential.accessToken).value
        return urlRequest.headers["Authorization"] == bearerToken
    }
}
