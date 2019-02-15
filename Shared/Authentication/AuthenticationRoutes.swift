//
//  AuthorizationRoutes.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Foundation

struct RouteInfo: Alamofire.URLRequestConvertible {
    let route: AuthenticationRoute
    let baseURL: URL

    func asURLRequest() throws -> URLRequest {
        return try self.route.asURLRequestWith(baseURL: self.baseURL)
    }
}

enum AuthenticationRoute {
    case token(authorizationCode: String)
    case refreshToken(token: String)
    case revokeToken(token: String)

    func asURLRequestWith(baseURL: URL) throws -> URLRequest {
        let baseRequest =  try URLRequest(url: baseURL.appendingPathComponent(self.path), method: self.method)
        let request: URLRequest
        if let parameters = self.parameters {
            request = try URLEncoding.httpBody.encode(baseRequest, with: parameters)
        } else {
            request = baseRequest
        }
        return request
    }

    // MARK: - Private helpers

    private var clientID: String {
        guard let urlHandlerBase = Bundle.main.object(forInfoDictionaryKey: "ENV_URL_HANDLER"),
            let urlHandlerBaseStr = urlHandlerBase as? String else {
                print("Returning because ENV_URL_HANDLER isn't set!")
                return "https://home-assistant.io/iOS"
        }

        var clientID = "https://home-assistant.io/iOS"

        if urlHandlerBaseStr == "homeassistant-dev" {
            clientID = "https://home-assistant.io/iOS/dev-auth"
        } else if urlHandlerBaseStr == "homeassistant-beta" {
            clientID = "https://home-assistant.io/iOS/beta-auth"
        }
        return clientID
    }

    private var method: HTTPMethod {
        switch self {
        case .token:
            return .post
        case .refreshToken:
            return .post
        case .revokeToken:
            return .post
        }
    }

    private var parameters: Parameters? {
        switch self {
        case .token(let authorizationCode):
            return ["client_id": self.clientID, "grant_type": "authorization_code", "code": authorizationCode]
        case .refreshToken(let token):
            return ["client_id": self.clientID, "grant_type": "refresh_token", "refresh_token": token]
        case .revokeToken(let token):
            return ["action": "revoke", "token": token]
        }
    }

    private var path: String {
        switch self {
        case .token:
            return "/auth/token"
        case .refreshToken:
            return "/auth/token"
        case .revokeToken:
            return "/auth/token"
        }
    }
}
