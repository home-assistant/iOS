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
    enum WebhookParseError: Error {
        case couldNotDecode
    }

    // MARK: - Helper methods for reducing boilerplate.

    public func webhook(_ type: String, payload: Any, callingFunctionName: String) -> Promise<Void> {
        let request = WebhookRequest(type: type, data: payload)
        let result: Promise<Any> = webhookManager.sendEphemeral(request: request)
        return result.asVoid()
    }

    public func webhook(_ type: String, payload: Any, callingFunctionName: String) -> Promise<Any> {
        let request = WebhookRequest(type: type, data: payload)
        return webhookManager.sendEphemeral(request: request)
    }

    public func webhook<T: BaseMappable>(_ type: String, payload: Any,
                                         callingFunctionName: String) -> Promise<T> {
        firstly { () -> Promise<Any> in
            let request = WebhookRequest(type: type, data: payload)
            return webhookManager.sendEphemeral(request: request)
        }.map {
            if let result = Mapper<T>().map(JSONObject: $0) {
                return result
            } else {
                throw WebhookParseError.couldNotDecode
            }
        }
    }

    public func webhook<T: BaseMappable>(_ type: String, payload: Any,
                                         callingFunctionName: String) -> Promise<[T]> {
        return firstly { () -> Promise<Any> in
            let request = WebhookRequest(type: type, data: payload)
            return webhookManager.sendEphemeral(request: request)
        }.map {
            if let result = Mapper<T>(context: nil, shouldIncludeNilValues: false).mapArray(JSONObject: $0) {
                return result
            } else {
                throw WebhookParseError.couldNotDecode
            }
        }
    }
}
