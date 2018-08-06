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

public class AuthenticationAPI {
    public enum AuthenticationError: Error {
        case unexepectedType
    }

    public enum AuthenticationResponse {
        case invalid(updatedForm: DataEntryFlowForm)
        case valid(title: String, source: String, result: String)
    }

    public static func listProviders() -> Promise<[AuthenticationProvider]> {
        return Promise<[AuthenticationProvider]> { resolver in
            Alamofire.request(AuthenticationRoutes.providers).responseArray {
                (response: DataResponse<[AuthenticationProvider]>) in
                switch response.result {
                case .failure(let error):
                    resolver.reject(error)
                case .success(let value):
                    resolver.fulfill(value)
                }
            }
        }
    }

    public static func authenticationSchema(for provider: AuthenticationProvider) ->
        Promise<DataEntryFlowForm> {
            return firstly {
                Alamofire.request(AuthenticationRoutes.loginFlow(provider: provider)).responseJSON()
            }.done { json, response in
                let dictionary = JSON as! NSDictionary
                guard let resultType = dictionary["type"] as? String else {
                    throw AuthenticationError.unexepectedType
                }

                return


            }
//        return Promise<[AuthenticationProvider]> { resolver in
//            firstly {
//                Alamofire.request(AuthenticationRoutes.loginFlow(provider: provider)).responseJSON()
//                }.then { json, response in
//                    print("json")
//
//
//            }
//        }
    }
}
