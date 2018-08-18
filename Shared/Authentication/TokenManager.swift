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

    private var refreshToken: Promise<String> {
        guard let tokenInfo = self.tokenInfo else {
            return Promise(error: TokenError.tokenUnavailable)
        }

        if let refreshPromise = self.refreshPromiseCache {
            return refreshPromise
        }

        let promise = firstly {
            self.authenticationAPI.refreshTokenWith(tokenInfo: tokenInfo)
        }.map { tokenInfo -> String in
            Current.settingsStore.tokenInfo = tokenInfo
            return tokenInfo.accessToken
        }

        self.refreshPromiseCache = promise
        return promise
    }

    // MARK: - RequestRetrier

    public func should(_ manager: SessionManager, retry request: Request, with error: Error,
                       completion: @escaping RequestRetryCompletion) {
        guard let baseURL = Current.settingsStore.baseURL else {
            completion(false, 0)
            return
        }

        if request.request?.url?.baseURL == baseURL && request.response?.statusCode == 401 {
            // If this is a call to our server, and we failed with not authorized, try to refresh the token.
            _ = self.refreshToken.done { _ in
                // If we get a token, retry.
                completion(true, 0)
            }.catch { _ in
                // If not, ahh well.
                completion(false, 0)
            }
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
}
