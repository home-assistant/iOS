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
class WebhookHandler: RequestAdapter, RequestRetrier {
    private var webhookID: String
    private var externalURL: URL
    private var internalURLRaw: URL?
    private var internalSSID: String?
    private var internalURL: URL? {
        guard internalURLRaw != nil && internalSSID != nil else {
            return nil
        }
        #if os(iOS)
        if let internalSSID = self.internalSSID, internalSSID == ConnectionInfo.currentSSID() {
            return internalURLRaw
        }
        #endif
        return nil
    }
    private var remoteUIURL: URL?
    private var cloudhookURL: URL?

    private var activeURLType: WebhookURLType
    private var activeURL: URL

    private let lock = NSLock()

    private typealias URLWorksCompletion = (_ succeeded: Bool, _ url: URL?, _ urlType: WebhookURLType?) -> Void

    private var isTestingURL = false

    private var requestsToRetry: [RequestRetryCompletion] = []

    // MARK: - Initialization

    public init(webhookID: String, connectionInfo: ConnectionInfo, remoteUIURL: URL?, cloudhookURL: URL?) {
        self.webhookID = webhookID
        let path = "api/webhook/\(self.webhookID)"
        self.externalURL = connectionInfo.baseURL.appendingPathComponent(path, isDirectory: false)
        self.activeURL = self.externalURL
        self.activeURLType = .external

        if let cloudhookURL = cloudhookURL {
            self.cloudhookURL = cloudhookURL
            self.activeURLType = .cloudhook
            self.activeURL = cloudhookURL
        }

        if let remoteURL = remoteUIURL {
            self.remoteUIURL = remoteURL.appendingPathComponent(path, isDirectory: false)
            self.activeURLType = .remoteUI
            self.activeURL = remoteURL
        }

        if let url = connectionInfo.internalBaseURL, let ssid = connectionInfo.internalSSID {
            let builtURL = url.appendingPathComponent(path, isDirectory: false)
            self.internalURLRaw = builtURL
            self.internalSSID = ssid
            if let url = self.internalURL {
                self.activeURL = url
            }
        }
    }

    // MARK: - URLRequest helpers
    public var webhookPath: String {
        return "api/webhook/\(self.webhookID)"
    }

    public var webhookURL: URL {
        return self.activeURL
    }

    // MARK: - RequestAdapter
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest
        urlRequest.url = self.webhookURL
        return urlRequest
    }

    // MARK: - RequestRetrier
    func should(_ manager: SessionManager, retry request: Request, with error: Error,
                completion: @escaping RequestRetryCompletion) {
        lock.lock() ; defer { lock.unlock() }

        requestsToRetry.append(completion)

        self.testURLs { [weak self] succeeded, newURL, newURLType in
            guard let strongSelf = self else { return }
            strongSelf.lock.lock() ; defer { strongSelf.lock.unlock() }
            if succeeded, let newURL = newURL, let newURLType = newURLType {
                strongSelf.activeURL = newURL
                strongSelf.activeURLType = newURLType
            }
            strongSelf.requestsToRetry.forEach { $0(succeeded, 0.0) }
            strongSelf.requestsToRetry.removeAll()
            completion(succeeded, 0.0)
        }
    }

    private let sessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        return SessionManager(configuration: configuration)
    }()

    private func testURLs(_ completion: @escaping URLWorksCompletion) {
        guard !isTestingURL else { return }
        isTestingURL = true

        var urls: [WebhookURLType: URL] = [.external: self.externalURL]

        if let url = self.internalURL {
            urls[.internal] = url
        }
        if let url = self.cloudhookURL {
            urls[.cloudhook] = url
        }
        if let url = self.remoteUIURL {
            urls[.remoteUI] = url
        }

        for (urlType, url) in urls {
            Current.Log.verbose("Testing \(urlType) URL \(url)")
            if urlType == self.activeURLType {
                Current.Log.verbose("Not testing URL type \(self.activeURLType) as its currently failing")
                continue
            }
            let params = WebhookRequest(type: "get_config", data: [:]).toJSON()
            let enc = JSONEncoding.default
            let req = self.sessionManager.request(url, method: .post, parameters: params, encoding: enc)
            req.validate().responseJSON { [weak self] response in
                guard let strongSelf = self else { return }
                if response.result.value != nil {
                    Current.Log.info("Webhook URL update \(strongSelf.activeURLType) -> \(urlType)")
                    strongSelf.isTestingURL = false
                    completion(true, url, urlType)
                }
            }
        }

        completion(false, nil, nil)
    }
}

enum WebhookURLType: Int, CaseIterable {
    case `internal`
    case cloudhook
    case remoteUI
    case external
}
