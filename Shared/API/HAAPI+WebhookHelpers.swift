//
//  HAAPI+WebhookHelpers.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/26/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Alamofire
import Foundation
import PromiseKit
import ObjectMapper
import Sodium

extension HomeAssistantAPI {
    // MARK: - Helper methods for reducing boilerplate.

    func handleWebhookResponse<T>(response: DataResponse<T>, seal: Resolver<T>, callingFunctionName: String) {
        // Current.Log.verbose("\(callingFunctionName) response timeline: \(response.timeline)")

        if let cloudURL = response.response?.allHeaderFields["X-Cloud-Hook-URL"] as? String {
            Current.settingsStore.cloudhookURL = URL(string: cloudURL)
        }

        if response.response?.statusCode == 404 { // mobile_app not loaded
            return seal.reject(APIError.mobileAppComponentNotLoaded)
        } else if response.response?.statusCode == 410 { // config entry removed
            return seal.reject(APIError.webhookGone)
        }

        switch response.result {
        case .success(let value):
            seal.fulfill(value)
        case .failure(let error):
            Current.Log.error("Error on \(callingFunctionName) request: \(error)")
            seal.reject(error)
        }
    }

    func buildWebhookRequest(_ type: String, payload: Any) -> DataRequest {
        return self.webhookManager.request(self.webhookHandler.webhookURL, method: .post,
                                           parameters: WebhookRequest(type: type, data: payload).toJSON(),
                                           encoding: JSONEncoding.default)

    }

    public func webhook(_ type: String, payload: Any, callingFunctionName: String) -> Promise<String> {
        return Promise { seal in
            guard Current.settingsStore.webhookURL != nil else {
                Current.Log.error("No webhook URL is set when trying to use \(type)!")
                return seal.reject(APIError.cantBuildURL)
            }

            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseString { (response: DataResponse<String>) in
                    self.handleWebhookResponse(response: response, seal: seal,
                                               callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook(_ type: String, payload: Any, callingFunctionName: String) -> Promise<Any> {
        return Promise { seal in
            guard Current.settingsStore.webhookURL != nil else {
                Current.Log.error("No webhook URL is set when trying to use \(type)!")
                return seal.reject(APIError.cantBuildURL)
            }

            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseEncryptedJSON { (response: DataResponse<Any>) in
                    self.handleWebhookResponse(response: response, seal: seal,
                                               callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: BaseMappable>(_ type: String, payload: Any,
                                         callingFunctionName: String) -> Promise<T> {
        return Promise { seal in
            guard Current.settingsStore.webhookURL != nil else {
                Current.Log.error("No webhook URL is set when trying to use \(type)!")
                return seal.reject(APIError.cantBuildURL)
            }

            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseObject { (response: DataResponse<T>) in
                    self.handleWebhookResponse(response: response, seal: seal,
                                               callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: BaseMappable>(_ type: String, payload: Any,
                                         callingFunctionName: String) -> Promise<[T]> {
        return Promise { seal in
            guard Current.settingsStore.webhookURL != nil else {
                Current.Log.error("No webhook URL is set when trying to use \(type)!")
                return seal.reject(APIError.cantBuildURL)
            }

            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseArray { (response: DataResponse<[T]>) in
                    self.handleWebhookResponse(response: response, seal: seal,
                                               callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: ImmutableMappable>(_ type: String, payload: Any,
                                              callingFunctionName: String) -> Promise<[T]> {
        return Promise { seal in
            guard Current.settingsStore.webhookURL != nil else {
                Current.Log.error("No webhook URL is set when trying to use \(type)!")
                return seal.reject(APIError.cantBuildURL)
            }

            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseArray { (response: DataResponse<[T]>) in
                    self.handleWebhookResponse(response: response, seal: seal,
                                               callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: ImmutableMappable>(_ type: String, payload: Any,
                                              callingFunctionName: String) -> Promise<T> {
        return Promise { seal in
            guard Current.settingsStore.webhookURL != nil else {
                Current.Log.error("No webhook URL is set when trying to use \(type)!")
                return seal.reject(APIError.cantBuildURL)
            }

            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseObject { (response: DataResponse<T>) in
                    self.handleWebhookResponse(response: response, seal: seal,
                                               callingFunctionName: callingFunctionName)
            }

        }
    }

}
