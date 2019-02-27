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

extension HomeAssistantAPI {
    // MARK: - Helper methods for reducing boilerplate.

    func buildWebhookRequest(_ type: String, payload: [String: Any]) -> DataRequest {
        return Alamofire.request(Current.settingsStore.webhookURL!, method: .post,
                                 parameters: WebhookRequest(type: type, data: payload).toJSON(),
                                 encoding: JSONEncoding.default)
    }

    public func webhook(_ type: String, payload: [String: Any], callingFunctionName: String) -> Promise<String> {
        return Promise { seal in
            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseString { (response: DataResponse<String>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook(_ type: String, payload: [String: Any], callingFunctionName: String) -> Promise<Any> {
        return Promise { seal in
            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseJSON { (response: DataResponse<Any>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: BaseMappable>(_ type: String, payload: [String: Any],
                                         callingFunctionName: String) -> Promise<T> {
        return Promise { seal in
            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseObject { (response: DataResponse<T>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: BaseMappable>(_ type: String, payload: [String: Any],
                                         callingFunctionName: String) -> Promise<[T]> {
        return Promise { seal in
            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseArray { (response: DataResponse<[T]>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: ImmutableMappable>(_ type: String, payload: [String: Any],
                                              callingFunctionName: String) -> Promise<[T]> {
        return Promise { seal in
            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseArray { (response: DataResponse<[T]>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

    public func webhook<T: ImmutableMappable>(_ type: String, payload: [String: Any],
                                              callingFunctionName: String) -> Promise<T> {
        return Promise { seal in
            _ = self.buildWebhookRequest(type, payload: payload).validate()
                .responseObject { (response: DataResponse<T>) in
                    self.handleResponse(response: response, seal: seal,
                                        callingFunctionName: callingFunctionName)
            }

        }
    }

}
