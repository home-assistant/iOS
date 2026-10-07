import Alamofire
import Foundation
import HAKit
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

    /// Access tokens the server refused while their stored expiration still said they were valid.
    ///
    /// Tracked in memory because the persisted invalidation in `handleAccessTokenRejected` cannot be
    /// relied on: `ServerInfo` equality considers two tokens with the same access/refresh pair equal, so
    /// the server store drops a write that only pushes a token's expiration into the past as a no-op.
    /// Without this, every websocket reconnect and every request keeps re-sending a token the server has
    /// already rejected, which Home Assistant logs as invalid auth and eventually answers with an IP ban.
    private let rejectedAccessTokens = HAProtected<Set<String>>(value: [])

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

    /// Call after `revokeToken()` succeeded (the user logged out). Home Assistant drops the refresh
    /// token and with it every access token minted from it, so both are dead from that moment on;
    /// remembering the rejection keeps the app from re-sending them while the user logs back in, which
    /// the server would log as invalid auth and eventually answer with an IP ban.
    ///
    /// The expiration is pushed into the past on the same best-effort terms as
    /// `handleAccessTokenRejected`, so the invalidation outlives this process where it can be written.
    /// The token strings themselves stay put: clearing them is what `mirrorPlaceholderToken` is, which
    /// would make the server look like one restored from the keychain mirror.
    public func handleTokenRevoked() {
        let revokedToken = server.info.token.accessToken
        HANetworkingEnvironment.current.log.info("Access token \(revokedToken.hash) was revoked")
        rejectedAccessTokens.mutate { $0.insert(revokedToken) }
        server.update { $0.token.expiration = .distantPast }
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

    /// Call when the server answered a request with HTTP 401 for an access token this manager handed
    /// out. The client-side expiration said the token was still valid, yet the server rejected it —
    /// typically because its refresh token was revoked (device deleted from the HA profile) or the
    /// server was restored from a backup. Without this, every poll re-sends the same rejected token,
    /// which the server logs as invalid auth and eventually answers with an IP ban.
    ///
    /// Remembering the rejection makes every future `bearerToken` refuse to hand the token out and go
    /// through a refresh instead: either the refresh mints a working token, or it fails with
    /// 400...403 and the reauthentication-required flow kicks in — in both cases the rejected token is
    /// never sent again. The expiration is also pushed into the past, but only as a best effort: the
    /// store coalesces a write that changes nothing but the expiration (see `rejectedAccessTokens`), so
    /// it lands solely where there is no cache to coalesce against — an app extension invalidating a
    /// token the server just refused, which the other processes then read fresh.
    public func handleAccessTokenRejected(_ rejectedToken: String) {
        // A refresh may have already replaced the token by the time the 401 lands; only the
        // currently stored token must be invalidated, never its fresh successor.
        guard server.info.token.accessToken == rejectedToken else { return }
        HANetworkingEnvironment.current.log.error(
            "Server rejected access token \(rejectedToken.hash) before its expiration; forcing refresh"
        )
        rejectedAccessTokens.mutate { $0.insert(rejectedToken) }
        server.update { $0.token.expiration = .distantPast }
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

            if rejectedAccessTokens.read({ $0.contains(tokenInfo.accessToken) }) {
                HANetworkingEnvironment.current.log
                    .error("Token \(tokenInfo.accessToken.hash) was rejected by the server, refusing to reuse it")
                seal.reject(TokenError.expired)
                return
            }

            // Refresh a full minute early (matching `TokenInfo.needsRefresh`) so we never hand back a
            // token that lapses in flight — especially on slow watch/cloud paths where the round trip
            // can outlast a token with only seconds left, which the server then logs as invalid auth.
            if tokenInfo.expiration.addingTimeInterval(-60) > HANetworkingEnvironment.current.date() {
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

    /// Signs the request with the token in the store rather than with the credential Alamofire hands
    /// back.
    ///
    /// `AuthenticationInterceptor` keeps the credential it was built with and only replaces it after a
    /// refresh it drove itself. Re-authentication mints a token through an entirely different path (the
    /// login web view exchanging a fresh authorization code), so that snapshot outlives it: every
    /// request the session sends afterwards carries the access token the server already rejected, which
    /// Home Assistant logs as invalid auth, and since the session lives as long as the cached
    /// `HomeAssistantAPI`, only relaunching the app stopped it. The store is the single source of truth
    /// here, the same way `ServerRequestAdapter` resolves the active URL fresh per request.
    public func apply(_ credential: TokenInfo, to urlRequest: inout URLRequest) {
        urlRequest.headers.add(.authorization(bearerToken: server.info.token.accessToken))
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

    /// Compared against the stored token for the same reason `apply` signs with it: a 401 for a request
    /// that carried a superseded token has to be retried with the current one instead of being taken as
    /// a rejection of the token the interceptor still has cached.
    public func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: TokenInfo) -> Bool {
        let bearerToken = HTTPHeader.authorization(bearerToken: server.info.token.accessToken).value
        return urlRequest.headers["Authorization"] == bearerToken
    }
}
