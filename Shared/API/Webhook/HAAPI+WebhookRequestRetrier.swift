//
//  HAAPI+WebhookRequestRetrier.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/8/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import Alamofire

// Order to use URLs in
// 1. Internal URL if current SSID == previously stored SSID that confirms internal is available
// 2. Cloudhook
// 3. Remote UI (may require turning it on via REST API if available)
// 4. External URL
public class WebhookHandler: RequestAdapter, RequestRetrier {
    // MARK: - RequestAdapter
    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let connectionInfo = Current.settingsStore.connectionInfo else { return urlRequest }
        return try connectionInfo.adapt(urlRequest)
    }

    // MARK: - RequestRetrier
    public func should(_ manager: SessionManager, retry request: Request, with error: Error,
                       completion: @escaping RequestRetryCompletion) {
        // There's only two situations in which we should attempt to change the URL to a point where we may
        // be able to get working again:
        // 1. If remote UI is active and failure is low level (NSURLErrorDomain) which means snitun is down
        // 2. If internal URL is active but SSID doesn't match
        guard let connectionInfo = Current.settingsStore.connectionInfo else {
            Current.Log.error("Couldn't get Current.settingsStore.connectionInfo!")
            completion(false, 0)
            return
        }

        completion(connectionInfo.should(manager, retry: request, with: error), 0)
        return
    }
}
