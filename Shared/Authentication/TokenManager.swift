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
    private let baseURL: URL

    /// This should be set to enable the token manager to trigger re-authentication when needed.
    public var authenticationRequiredCallback: (() -> Promise<String>)?

    public var isAuthenticated: Bool {
        return self.tokenInfo != nil
    }

    public init(baseURL: URL, tokenInfo: TokenInfo? = nil) {
        self.baseURL = baseURL
        self.authenticationAPI = AuthenticationAPI(baseURL: baseURL)
        self.tokenInfo = tokenInfo
    }

    /// After authenticating with the server and getting a code, call this method to exchange the code for
    /// an auth token.
    /// - Parameter code: Code acquired by authenticating with an authenticaiton provider.
    public func initialTokenWithCode(_ code: String) -> Promise<String> {
        return self.authenticationAPI.fetchTokenWithCode(code).then { tokenInfo -> Promise<String> in
            self.tokenInfo = tokenInfo
            Current.settingsStore.tokenInfo = tokenInfo
            Current.settingsStore.baseURL = self.baseURL
            return self.bearerToken
        }
    }

    public var bearerToken: Promise<String> {
        return firstly {
            self.currentToken
        }.recover { error -> Promise<String> in
            guard let tokenError = error as? TokenError, tokenError == TokenError.expired,
                self.tokenInfo != nil else {
                throw error
            }

            return self.refreshToken
        }
    }

    // MARK: - RequestRetrier

    public func should(_ manager: SessionManager, retry request: Request, with error: Error,
                       completion: @escaping RequestRetryCompletion) {
        guard let baseURL = Current.settingsStore.baseURL else {
            completion(false, 0)
            return
        }

        if request.retryCount > 3 {
            print("Reached maximum retries for request: \(request)")
            completion(false, 0)
            return
        }

        if request.request?.url?.host == baseURL.host && request.request?.url?.scheme == baseURL.scheme
            && request.response?.statusCode == 401 {
            // If this is a call to our server, and we failed with not authorized, try to refresh the token.
            _ = self.refreshToken.done { _ in
                guard self.tokenInfo != nil else {
                    print("Token Info not avaialble after refresh")
                    completion(false, 0)
                    return
                }

                // If we get a token, retry.
                completion(true, 2)
            }.catch { _ in
                // If not, ahh well.
                completion(false, 0)
            }
        } else {
            completion(false, 0)
        }
    }

    // MARK: - RequestAdapter

    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let tokenInfo = self.tokenInfo else {
            return urlRequest
        }

        var newRequest = urlRequest
        newRequest.setValue("Bearer \(tokenInfo.accessToken)", forHTTPHeaderField: "Authorization")
        return newRequest
    }

    // MARK: - Private helpers

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
                seal.reject(TokenError.expired)
            }
        }
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
