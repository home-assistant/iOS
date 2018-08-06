//
//  AuthorizationRoutes.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Foundation
let baseURLString = "http://192.168.86.187:8123"
let kClientId = "https://www.home-assistant.io/ios"
let kRedirectURI = "homeassistant://"

enum AuthenticationRoutes: URLRequestConvertible {
    case providers
    case loginFlow(provider: AuthenticationProvider)

    func asURLRequest() throws -> URLRequest {
        let baseURL = try baseURLString.asURL()
        var request = URLRequest(url: baseURL.appendingPathComponent(self.path))
        request.httpMethod = self.method.rawValue

        return request
    }

    // MARK: - Private helpers
    private var method: HTTPMethod {
        switch self {
        case .providers:
            return .get
        case .loginFlow:
            return .post
        }
    }

    private var parameters: Parameters? {
        switch self {
        case .providers:
            return nil
        case .loginFlow(let provider):
            let handler = [provider.type, provider.id]
            return ["handler": handler, "redirect_uri": kRedirectURI, "client_id": kClientId]
        }
    }

    private var path: String {
        switch self {
        case .providers:
            return "/auth/providers"
        case .loginFlow:
            return "/auth/login_flow"
        }
    }
}
