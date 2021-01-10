//
//  TokenManager.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/11/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Foundation
import PromiseKit

public class TokenManager {
    public enum TokenError: Error {
        case tokenUnavailable
        case expired
        case connectionFailed
    }

    private var tokenInfo: TokenInfo?
    private var authenticationAPI: AuthenticationAPI
    private let forcedConnectionInfo: ConnectionInfo?

    private class RefreshPromiseCache {
        // we can be asked to refresh from any queue - alamofire's utility queue, webview's main queue, so guard
        // accessing the underlying promise here without being on the queue is programmer error
        let queue: DispatchQueue
        private let queueSpecific = DispatchSpecificKey<Bool>()

        init() {
            queue = DispatchQueue(label: "refresh-promise-cache-mutex", qos: .userInitiated)
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

    public init(tokenInfo: TokenInfo? = nil, forcedConnectionInfo: ConnectionInfo? = nil) {
        self.authenticationAPI = AuthenticationAPI(forcedConnectionInfo: forcedConnectionInfo)
        self.tokenInfo = tokenInfo
        self.forcedConnectionInfo = forcedConnectionInfo
    }

    private var connectionInfo: ConnectionInfo? {
        forcedConnectionInfo ?? Current.settingsStore.connectionInfo
    }

    /// After authenticating with the server and getting a code, call this method to exchange the code for
    /// an auth token.
    /// - Parameter code: Code acquired by authenticating with an authenticaiton provider.
    public func initialTokenWithCode(_ code: String) -> Promise<TokenInfo> {
        return self.authenticationAPI.fetchTokenWithCode(code).then { tokenInfo -> Promise<TokenInfo> in
            self.tokenInfo = tokenInfo
            Current.settingsStore.tokenInfo = tokenInfo
            return Promise.value(tokenInfo)
        }
    }

    // Request the server revokes the current token.
    public func revokeToken() -> Promise<Bool> {
        guard let tokenInfo = self.tokenInfo else {
            return Promise(error: TokenError.tokenUnavailable)
        }

        return self.authenticationAPI.revokeToken(tokenInfo: tokenInfo)
    }

    public var bearerToken: Promise<String> {
        return firstly {
            self.currentToken
        }.recover { [self] error -> Promise<String> in
            guard let tokenError = error as? TokenError, tokenError == TokenError.expired,
                self.tokenInfo != nil else {
                Current.Log.verbose("Unable to recover from token error! \(error)")
                throw error
            }

            return refreshToken().map(\.accessToken)
        }
    }

    public func authDictionaryForWebView(forceRefresh: Bool) -> Promise<[String: Any]> {
        return firstly { () -> Promise<String> in
            if forceRefresh {
                Current.Log.info("forcing a refresh of token")
                return refreshToken().map(\.accessToken)
            } else {
                Current.Log.info("using existing token")
                return bearerToken
            }
        }.map { _ -> [String: Any] in
            // TokenInfo is refreshed at this point.
            guard let info = self.tokenInfo  else {
                throw TokenError.tokenUnavailable
            }

            var dictionary: [String: Any] = [:]
            dictionary["access_token"] = info.accessToken
            dictionary["expires_in"] = Int(info.expiration.timeIntervalSince(Current.date()))
            return dictionary
        }
    }

    // MARK: - Private helpers

    private func loggableString(for url: URL) -> String {
        guard let urlType = connectionInfo?.getURLType(url) else {
            return "[Non-HASS URL]\(url.path)"
        }

        return "[\(urlType.description)]\(url.path)"
    }

    private var currentToken: Promise<String> {
        return Promise<String> { seal in
            guard let tokenInfo = self.tokenInfo else {
                throw TokenError.tokenUnavailable
            }

            // Add a margin to -10 seconds so that we never get into a state where we return a token
            // that immediately fails.
            if tokenInfo.expiration.addingTimeInterval(-10) > Current.date() {
                seal.fulfill(tokenInfo.accessToken)
            } else {
                if let expirationAmount = Calendar.current.dateComponents([.second], from: tokenInfo.expiration,
                                                                          to: Current.date()).second {
                    Current.Log.error("Token is expired by \(expirationAmount) seconds: \(tokenInfo.accessToken)")
                } else {
                    Current.Log.error("Token is expired by an unknown amount of time: \(tokenInfo.accessToken)")
                }

                seal.reject(TokenError.expired)
            }
        }
    }

    private func refreshToken() -> Promise<TokenInfo> {
        refreshPromiseCache.queue.sync {
            guard let tokenInfo = self.tokenInfo else {
                Current.Log.error("no token info, can't refresh")
                return Promise(error: TokenError.tokenUnavailable)
            }

            if let refreshPromise = self.refreshPromiseCache.promise {
                Current.Log.info("using cached refreshToken promise")
                return refreshPromise
            }

            let promise: Promise<TokenInfo> = firstly {
                self.authenticationAPI.refreshTokenWith(tokenInfo: tokenInfo)
            }.get { tokenInfo in
                Current.Log.info("storing refresh token")
                Current.settingsStore.tokenInfo = tokenInfo
                self.tokenInfo = tokenInfo
            }.ensure(on: refreshPromiseCache.queue) {
                Current.Log.info("reset cached refreshToken promise")
                self.refreshPromiseCache.promise = nil
            }.tap { result in
                switch result {
                case .rejected(let error):
                    Current.Log.error("refresh token got error: \(error)")

                    if let networkError = error as? AFError, let statusCode = networkError.responseCode,
                        statusCode == 400 {
                        /// Server rejected the refresh token. All is lost.
                        let event = ClientEvent(
                            text: "Refresh token is invalid, showing onboarding",
                            type: .networkRequest
                        )
                        Current.clientEventStore.addEvent(event)

                        self.tokenInfo = nil
                        Current.settingsStore.tokenInfo = nil
                        Current.onboardingObservation.needed(.error)
                    }
                case .fulfilled:
                    Current.Log.info("refresh token got success")
                }
            }

            Current.Log.info("starting refreshToken cache")
            self.refreshPromiseCache.promise = promise
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
        AuthenticationInterceptor(authenticator: self, credential: tokenInfo, refreshWindow: nil)
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
