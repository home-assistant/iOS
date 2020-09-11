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

public class TokenManager: RequestAdapter, RequestRetrier {
    public enum TokenError: Error {
        case tokenUnavailable
        case expired
        case connectionFailed
    }

    private var tokenInfo: TokenInfo?
    private var authenticationAPI: AuthenticationAPI

    private class RefreshPromiseCache {
        // we can be asked to refresh from any queue - alamofire's utility queue, webview's main queue, so guard
        // accessing the underlying promise here without being on the queue is programmer error
        let queue: DispatchQueue
        private let queueSpecific = DispatchSpecificKey<Bool>()

        init() {
            queue = DispatchQueue(label: "refresh-promise-cache-mutex", qos: .userInitiated)
            queue.setSpecific(key: queueSpecific, value: true)
        }

        private var underlyingPromise: Promise<String>?

        var promise: Promise<String>? {
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
    private let connectionInfo: ConnectionInfo

    public var isAuthenticated: Bool {
        return self.tokenInfo != nil
    }

    public init(connectionInfo: ConnectionInfo, tokenInfo: TokenInfo? = nil) {
        self.connectionInfo = connectionInfo
        self.authenticationAPI = AuthenticationAPI(connectionInfo: self.connectionInfo)
        self.tokenInfo = tokenInfo
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
        }.recover { error -> Promise<String> in
            guard let tokenError = error as? TokenError, tokenError == TokenError.expired,
                self.tokenInfo != nil else {
                Current.Log.verbose("Unable to recover from token error! \(error)")
                throw error
            }

            return self.refreshToken
        }
    }

    public func authDictionaryForWebView(forceRefresh: Bool) -> Promise<[String: Any]> {
        return firstly { () -> Promise<String> in
            if forceRefresh {
                Current.Log.info("forcing a refresh of token")
                return refreshToken
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

    // MARK: - RequestRetrier

    public func should(_ manager: SessionManager, retry request: Request, with error: Error,
                       completion: @escaping RequestRetryCompletion) {
        guard let connectionInfo = Current.settingsStore.connectionInfo,
            let requestURL = request.request?.url else {
            completion(false, 0)
            return
        }

        if request.retryCount > 5 {
            Current.Log.warning("Reached maximum retries for request: \(self.loggableString(for: requestURL))")
            let message = "Failed to make request: \(self.loggableString(for: requestURL)) after 3 tries"
            let event = ClientEvent(text: message, type: .networkRequest)
            Current.clientEventStore.addEvent(event)
            completion(false, 0)
            return
        }

        if case TokenError.expired = error, self.isURLValid(requestURL, for: connectionInfo) {
            // If this is a call to our server, and we failed with not authorized, try to refresh the token.
            _ = self.refreshToken.done { _ in
                guard self.tokenInfo != nil else {
                    Current.Log.warning("Token Info not avaialble after refresh")
                    completion(false, 0)
                    return
                }

                // If we get a token, retry.
                completion(true, 0)
            }.catch { _ in
                // If not, ahh well.
                completion(false, 0)
            }
        } else if connectionInfo.should(manager, retry: request, with: error) {
            completion(true, 0)
        } else {
            let urlError = error as NSError
            if urlError.domain == NSURLErrorDomain, urlError.code == NSURLErrorTimedOut {
                // Retry timeouts.
                let message = "Retry #\(request.retryCount) request: \(self.loggableString(for: requestURL))"
                let event = ClientEvent(text: message, type: .networkRequest)
                Current.clientEventStore.addEvent(event)
                completion(true, TimeInterval(2 * request.retryCount))
            } else if let error = error as? AFError, error.responseCode == 401 {
                let event = ClientEvent(text: "Server indicated token is invalid, onboarding", type: .networkRequest)
                Current.clientEventStore.addEvent(event)

                completion(false, 0)

                DispatchQueue.main.async {
                    Current.onboardingObservation.needed(.error)
                }
            } else {
                completion(false, 0)
            }
        }
    }

    // MARK: - RequestAdapter

    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let url = urlRequest.url else {
            return urlRequest
        }

        var newRequest = urlRequest

        let adaptedURL = Current.settingsStore.connectionInfo?.adaptAPIURL(url)

        if newRequest.url != adaptedURL {
            newRequest.url = adaptedURL
        }

        let isTokenRequest = url.path == "/auth/token"
        guard !isTokenRequest else {
            return urlRequest
        }

        guard let tokenInfo = self.tokenInfo else {
            Current.Log.error("Token is unavailable")
            throw TokenError.tokenUnavailable
        }

        guard tokenInfo.needsRefresh == false else {
            Current.Log.error("Token is expired")
            throw TokenError.expired
        }

        newRequest.setValue("Bearer \(tokenInfo.accessToken)", forHTTPHeaderField: "Authorization")
        return newRequest
    }

    // MARK: - Private helpers

    private func loggableString(for url: URL) -> String {
        guard let urlType = Current.settingsStore.connectionInfo?.getURLType(url) else {
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

    private func isURLValid(_ url: URL, for connectionInfo: ConnectionInfo) -> Bool {
        return Current.settingsStore.connectionInfo?.checkURLMatches(url) ?? false
    }

    private func url(_ url: URL, matchesPrefixOf referenceURL: URL) -> Bool {
        guard let connectionInfo = Current.settingsStore.connectionInfo else { return false }
        return connectionInfo.checkURLMatches(url)
    }

    private var refreshToken: Promise<String> {
        refreshPromiseCache.queue.sync {
            guard let tokenInfo = self.tokenInfo else {
                Current.Log.error("no token info, can't refresh")
                return Promise(error: TokenError.tokenUnavailable)
            }

            if let refreshPromise = self.refreshPromiseCache.promise {
                Current.Log.info("using cached refreshToken promise")
                return refreshPromise
            }

            let promise: Promise<String> = firstly {
                self.authenticationAPI.refreshTokenWith(tokenInfo: tokenInfo)
            }.map { tokenInfo in
                Current.Log.info("storing refresh token")
                Current.settingsStore.tokenInfo = tokenInfo
                self.tokenInfo = tokenInfo
                return tokenInfo.accessToken
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
