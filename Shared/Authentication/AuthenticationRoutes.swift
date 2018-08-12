//
//  AuthorizationRoutes.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Foundation
let baseURLString = "http://localhost.charlesproxy.com:8123"
let kClientId = "https://www.home-assistant.io/ios"
let kRedirectURI = "https://www.home-assistant.io/ios"

enum AuthenticationRoutes: Alamofire.URLRequestConvertible {
   case token(authorizationCode: String)
    case refreshToken(token: String)

    func asURLRequest() throws -> URLRequest {
        let baseURL = try baseURLString.asURL()
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
        }
    }

    private var parameters: Parameters? {
        switch self {
        case .token(let authorizationCode):
            return ["client_id": kClientId, "grant_type": "authorization_code", "code": authorizationCode]
        case .refreshToken(let token):
            return ["client_id": kClientId, "grant_type": "refresh_token", "refresh_token": token]
        }
    }

    private var path: String {
        switch self {
        case .token:
            return "/auth/token"
        case .refreshToken:
            return "/auth/token"
        }
    }
}
