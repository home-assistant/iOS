//
//  AuthorizationAPI.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import PromiseKit
import Alamofire
import AlamofireObjectMapper
import Foundation
import ObjectMapper

typealias URLRequestConvertible = Alamofire.URLRequestConvertible

public class AuthenticationAPI {
    public enum AuthenticationError: Error {
        case unexepectedType
        case unexpectedResponse
    }

    public static func refreshTokenWith(token: String) -> Promise<TokenInfo> {
        return Promise { seal in
            let request = Alamofire.request(AuthenticationRoutes.refreshToken(token: token))
            debugPrint(request)
            request.responseObject { (dataresponse: DataResponse<TokenInfo>) in
                switch dataresponse.result {
                case .failure(let error):
                    seal.reject(error)
                case .success(let value):
                    seal.fulfill(value)
                }
                return
            }
        }
    }

    public static func fetchTokenWithCode(_ authorizationCode: String) -> Promise<TokenInfo> {
        return Promise { seal in            
            let request = Alamofire.request(AuthenticationRoutes.token(authorizationCode: authorizationCode))
            debugPrint(request)
            request.responseObject { (dataresponse: DataResponse<TokenInfo>) in
                switch dataresponse.result {
                case .failure(let error):
                    seal.reject(error)
                case .success(let value):
                    seal.fulfill(value)
                }
                return
            }
        }
    }
}
