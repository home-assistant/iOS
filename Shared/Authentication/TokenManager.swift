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
    private var refreshPromiseCache: Promise<String>?
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

    public var authDictionaryForWebView: Promise<[String: Any]> {
        return firstly {
                self.bearerToken
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

        guard !tokenInfo.needsRefresh else {
            Current.Log.error("Token is expired")
            throw TokenError.expired
        }

        let urlText = self.loggableString(for: url)
        let networkEvent = ClientEvent(text: urlText, type: .networkRequest)
        Current.clientEventStore.addEvent(networkEvent)
        newRequest.setValue("Bearer \(tokenInfo.accessToken)", forHTTPHeaderField: "Authorization")
        return newRequest
    }

    // MARK: - Private helpers

    private func loggableString(for url: URL) -> String {
        guard let urlType = Current.settingsStore.connectionInfo?.getURLType(url) else {
            return "[Non-HASS URL]\(url.path)"
        }

        let urlText: String

        switch urlType {
        case .internal:
            urlText = L10n.Settings.ConnectionSection.InternalBaseUrl.title
        case .external:
            urlText = L10n.Settings.ConnectionSection.ExternalBaseUrl.title
        case .remoteUI:
            urlText = L10n.Settings.ConnectionSection.RemoteUiUrl.title
        }

        return "[\(urlText)]\(url.path)"
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

    private var newCodePromise: Promise<Void>?
    private var refreshToken: Promise<String> {
        guard let tokenInfo = self.tokenInfo else {
            return Promise(error: TokenError.tokenUnavailable)
        }

        if let refreshPromise = self.refreshPromiseCache {
            return refreshPromise
        }

        let promise: Promise<String> =
            self.authenticationAPI.refreshTokenWith(tokenInfo: tokenInfo).map { tokenInfo in
            self.refreshPromiseCache = nil
            Current.settingsStore.tokenInfo = tokenInfo
            self.tokenInfo = tokenInfo
            return tokenInfo.accessToken
        }.ensure {
            self.refreshPromiseCache = nil
        }

        promise.catch { error in
            if let networkError = error as? AFError, let statusCode = networkError.responseCode,
                statusCode == 400 {
                /// Server rejected the refresh token. All is lost.
                self.tokenInfo = nil
                Current.settingsStore.tokenInfo = nil
                Current.signInRequiredCallback?()
            }
        }

        self.refreshPromiseCache = promise
        return promise
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
