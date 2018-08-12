//
//  TokenManager.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/11/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import PromiseKit

public struct TokenManager {
    public enum TokenError : Error {
        case tokenUnavailable
        case expired
        case connectionFailed
    }

    private var tokenInfo: TokenInfo?

    public var bearerToken: Promise<String> {
        return firstly {
            self.currentToken
        }.recover { error -> Promise<String> in
            guard let tokenError = error as? TokenError, tokenError == TokenError.expired,
                let tokenInfo = self.tokenInfo else {
                throw error
            }

            return firstly {
                AuthenticationAPI.refreshTokenWith(token: tokenInfo.refreshToken)
            }.map {
                $0.accessToken
            }
        }
    }
    
    private var currentToken: Promise<String> {
        return Promise<String> { seal in
            guard let tokenInfo = self.tokenInfo else {
                throw TokenError.tokenUnavailable
            }

            // Add a margin to -10 seconds so that we never get into a state where we return a token
            // that immediately fails.
            if tokenInfo.expiration < Current.date().addingTimeInterval(-10) {
                seal.fulfill(tokenInfo.accessToken)
            } else {
                seal.reject(TokenError.expired)
            }
        }
    }
}
