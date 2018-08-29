//
//  HAAPI+RequestHelpers.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/12/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Crashlytics
import Foundation
import PromiseKit
import ObjectMapper

extension HomeAssistantAPI {
    // MARK: - Helper methods for reducing boilerplate.

    func handleResponse<T>(response: DataResponse<T>, seal: Resolver<T>, callingFunctionName: String) {
        switch response.result {
        case .success(let value):
            seal.fulfill(value)
        case .failure(let error):
            CLSLogv("Error on \(callingFunctionName)() request: %@",
                getVaList([error.localizedDescription]))
            Crashlytics.sharedInstance().recordError(error)
            seal.reject(error)
        }
    }

    func request(path: String, callingFunctionName: String, method: HTTPMethod = .get,
                 parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default,
                 headers: HTTPHeaders? = nil) -> Promise<String> {
        return Promise { seal in
            let url = self.connectionInfo.activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding,
                                headers: headers)
                .validate()
                .responseString { (response: DataResponse<String>) in
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
            let url = self.connectionInfo.activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: DataResponse<T>) in
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
            let url = self.connectionInfo.activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseArray { (response: DataResponse<[T]>) in
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
           let url = self.connectionInfo.activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseArray { (response: DataResponse<[T]>) in
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
            let url = self.connectionInfo.activeAPIURL.appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: DataResponse<T>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }
}
