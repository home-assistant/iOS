//
//  AuthenticationAPI.swift
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
    let connectionInfo: ConnectionInfo
    public enum AuthenticationError: Error {
        case unexepectedType
        case unexpectedResponse
        case invalidCode
    }

    init(connectionInfo: ConnectionInfo) {
        self.connectionInfo = connectionInfo
    }

    public func refreshTokenWith(tokenInfo: TokenInfo) -> Promise<TokenInfo> {
        return Promise { seal in
            let token = tokenInfo.refreshToken
            let routeInfo = RouteInfo(route: AuthenticationRoute.refreshToken(token: token),
                                      baseURL: self.connectionInfo.activeURL)
            let request = Alamofire.request(routeInfo)
            let context = TokenInfo.TokenInfoContext(oldTokenInfo: tokenInfo)
            request.validate().responseObject(context: context) { (dataresponse: DataResponse<TokenInfo>) in
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

    public func revokeToken(tokenInfo: TokenInfo) -> Promise<Bool> {
        return Promise { seal in
            let token = tokenInfo.accessToken
            let routeInfo = RouteInfo(route: AuthenticationRoute.revokeToken(token: token),
                                      baseURL: self.connectionInfo.activeURL)
            let request = Alamofire.request(routeInfo)
            request.validate().response { response in
                // https://developers.home-assistant.io/docs/en/auth_api.html#revoking-a-refresh-token says:
                //
                // The request will always respond with an empty body and HTTP status 200,
                // regardless if the request was successful.
                seal.fulfill(true)
                return
            }
        }
    }

    public func fetchTokenWithCode(_ authorizationCode: String) -> Promise<TokenInfo> {
        return Promise { seal in
            let routeInfo = RouteInfo(route: AuthenticationRoute.token(authorizationCode: authorizationCode),
                                      baseURL: self.connectionInfo.activeURL)
            let request = Alamofire.request(routeInfo)
            request.validate().responseObject { (dataresponse: DataResponse<TokenInfo>) in
                switch dataresponse.result {
                case .failure(let networkError):

                    guard case let AFError.responseValidationFailed(reason: reason) = networkError,
                        case let AFError.ResponseValidationFailureReason.unacceptableStatusCode(code: code)
                        = reason, code == 400, let errorData = dataresponse.data else {
                            seal.reject(networkError)
                            return
                    }
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(with: errorData,
                                                                          options: .allowFragments)
                        if let errorDictionary = jsonObject as? [String: AnyObject],
                            let errorString = errorDictionary["error_description"] as? String,
                            errorString == "Invalid code" {
                            seal.reject(AuthenticationError.invalidCode)
                            return
                        }
                    } catch {
                        print("Error deserializing failure json response: \(error)")
                    }
                case .success(let value):
                    seal.fulfill(value)
                }
                return
            }
        }
    }
}
