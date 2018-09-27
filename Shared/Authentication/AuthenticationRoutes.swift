//
//  AuthorizationRoutes.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Foundation

let kClientId = "https://home-assistant.io/iOS"
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
            return ["client_id": kClientId, "grant_type": "authorization_code", "code": authorizationCode]
        case .refreshToken(let token):
            return ["client_id": kClientId, "grant_type": "refresh_token", "refresh_token": token]
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
