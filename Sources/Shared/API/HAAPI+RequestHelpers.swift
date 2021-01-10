//
//  HAAPI+RequestHelpers.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/12/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Foundation
import PromiseKit
import ObjectMapper

extension HomeAssistantAPI {
    // MARK: - Helper methods for reducing boilerplate.

    func handleResponse<T>(response: AFDataResponse<T>, seal: Resolver<T>, callingFunctionName: String) {
        // Current.Log.verbose("\(callingFunctionName) response timeline: \(response.timeline)")
        switch response.result {
        case .success(let value):
            seal.fulfill(value)
        case .failure(let error):
            Current.Log.error("Error on \(callingFunctionName) request: \(error)")
            seal.reject(error)
        }
    }

    func request(path: String, callingFunctionName: String, method: HTTPMethod = .get,
                 parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default,
                 headers: HTTPHeaders? = nil) -> Promise<String> {
        return Promise { seal in
            let url = try connectionInfo().activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding,
                                headers: headers)
                .validate()
                .responseString { (response: AFDataResponse<String>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    func request<T: BaseMappable>(path: String, callingFunctionName: String, method: HTTPMethod = .get,
                                  parameters: Parameters? = nil,
                                  encoding: ParameterEncoding = URLEncoding.default,
                                  headers: HTTPHeaders? = nil) -> Promise<T> {
        return Promise { seal in
            let url = try connectionInfo().activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: AFDataResponse<T>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    func request<T: BaseMappable>(path: String, callingFunctionName: String, method: HTTPMethod = .get,
                                  parameters: Parameters? = nil,
                                  encoding: ParameterEncoding = URLEncoding.default,
                                  headers: HTTPHeaders? = nil) -> Promise<[T]> {
        return Promise { seal in
            let url = try connectionInfo().activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseArray { (response: AFDataResponse<[T]>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    func request<T: ImmutableMappable>(path: String, callingFunctionName: String, method: HTTPMethod = .get,
                                       parameters: Parameters? = nil,
                                       encoding: ParameterEncoding = URLEncoding.default,
                                       headers: HTTPHeaders? = nil) -> Promise<[T]> {
        return Promise { seal in
            let url = try connectionInfo().activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseArray { (response: AFDataResponse<[T]>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    func request<T: ImmutableMappable>(path: String, callingFunctionName: String, method: HTTPMethod = .get,
                                       parameters: Parameters? = nil,
                                       encoding: ParameterEncoding = URLEncoding.default,
                                       headers: HTTPHeaders? = nil) -> Promise<T> {
        return Promise { seal in
            let url = try connectionInfo().activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: AFDataResponse<T>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    func requestImmutable<T: ImmutableMappable>(path: String, callingFunctionName: String, method: HTTPMethod = .get,
                                                parameters: Parameters? = nil,
                                                encoding: ParameterEncoding = URLEncoding.default,
                                                headers: HTTPHeaders? = nil) -> Promise<T> {
        return Promise { seal in
            let url = try connectionInfo().activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: AFDataResponse<T>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }
}
