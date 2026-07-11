import Alamofire
import Foundation
import PromiseKit

public final class TokenManager: @unchecked Sendable {
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
    ) async throws -> TokenInfo {
        guard let url = await connectionInfo.activeURL() else {
            throw ServerConnectionError.noActiveURL("Unknown - Initial token config")
        }

        let exceptions = connectionInfo.securityExceptions
        let clientCertificate = connectionInfo.clientCertificate

        return try await AuthenticationAPI.fetchToken(
            authorizationCode: code,
            baseURL: url,
            exceptions: exceptions,
            clientCertificate: clientCertificate
        ).asyncValue()
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
                HANetworkingEnvironment.current.log.verbose("Unable to recover from token error! \(error)")
                throw error
            }

            return refreshToken().map {
                HANetworkingEnvironment.current.log.info("providing token \($0.accessToken.hash)")
                return ($0.accessToken, $0.expiration)
            }
        }
    }

    public func authDictionaryForWebView(forceRefresh: Bool) -> Promise<[String: Any]> {
        firstly { () -> Promise<(String, Date)> in
            if forceRefresh {
                HANetworkingEnvironment.current.log.info("forcing a refresh of token")
                return refreshToken().map { ($0.accessToken, $0.expiration) }
            } else {
                HANetworkingEnvironment.current.log.info("using existing token")
                return bearerToken
            }
        }.map { token, expiration -> [String: Any] in
            HANetworkingEnvironment.current.log.info("creating webview token with \(token.hash)")
            var dictionary: [String: Any] = [:]
            dictionary["access_token"] = token
            dictionary["expires_in"] = Int(expiration.timeIntervalSince(HANetworkingEnvironment.current.date()))
            return dictionary
        }
    }

    // MARK: - Private helpers

    private var currentToken: Promise<(String, Date)> {
        Promise<(String, Date)> { seal in
            let tokenInfo = server.info.token

            // Add a margin to -10 seconds so that we never get into a state where we return a token
            // that immediately fails.
            if tokenInfo.expiration.addingTimeInterval(-10) > HANetworkingEnvironment.current.date() {
                seal.fulfill((tokenInfo.accessToken, tokenInfo.expiration))
            } else {
                if let expirationAmount = Calendar.current.dateComponents(
                    [.second],
                    from: tokenInfo.expiration,
                    to: HANetworkingEnvironment.current.date()
                ).second {
                    HANetworkingEnvironment.current.log
                        .error("Token \(tokenInfo.accessToken.hash) is expired by \(expirationAmount) seconds")
                } else {
                    HANetworkingEnvironment.current.log
                        .error("Token \(tokenInfo.accessToken.hash) is expired by unknown")
                }

                seal.reject(TokenError.expired)
            }
        }
    }

    private func refreshToken() -> Promise<TokenInfo> {
        refreshPromiseCache.queue.sync { [self, server] in
            let tokenInfo = server.info.token

            if let refreshPromise = refreshPromiseCache.promise {
                HANetworkingEnvironment.current.log.info("using cached refreshToken promise")
                return refreshPromise
            }

            let promise: Promise<TokenInfo> = firstly {
                authenticationAPI.refreshTokenWith(tokenInfo: tokenInfo)
            }.get { [server] tokenInfo in
                HANetworkingEnvironment.current.log.info("storing refresh token")
                server.info.token = tokenInfo
            }.ensure(on: refreshPromiseCache.queue) { [self] in
                HANetworkingEnvironment.current.log.info("reset cached refreshToken promise")
                refreshPromiseCache.promise = nil
            }.tap { [server] result in
                switch result {
                case let .rejected(error):
                    HANetworkingEnvironment.current.log.error("refresh token got error: \(error)")

                    if let underlying = error.authenticationAPIError,
                       underlying.shouldRequireReauthentication {
                        /// Server rejected the refresh token. All is lost. HACore performs the actual
                        /// client-event log + unsubscribe + disconnect + onboarding-needed via this seam.
                        HANetworkingEnvironment.current.handleReauthenticationRequired(
                            server,
                            underlying.statusCode,
                            String(describing: underlying)
                        )
                    }
                case .fulfilled:
                    HANetworkingEnvironment.current.log.info("refresh token got success")
                }
            }

            HANetworkingEnvironment.current.log.info("starting refreshToken cache")
            refreshPromiseCache.promise = promise
            return promise
        }
    }
}

// `TokenError`'s localized `errorDescription` lives in the Shared module
// (HANetworkingLocalization.swift); L10n isn't available in this package.

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
