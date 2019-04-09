//
//  HAAPI+WebhookRequestRetrier.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/8/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit

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

    private let lock = NSRecursiveLock()

    private typealias URLWorksCompletion = (_ succeeded: Bool, _ url: URL?, _ urlType: WebhookURLType?) -> Void

    private var isTestingURL = false

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
            let url = remoteURL.appendingPathComponent(path, isDirectory: false)
            self.remoteUIURL = url
            self.activeURLType = .remoteUI
            self.activeURL = url
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
        let newURL = self.webhookURL
        guard urlRequest.url != newURL else {
            return urlRequest
        }

        var urlRequest = urlRequest
        urlRequest.url = newURL
        return urlRequest
    }

    // MARK: - RequestRetrier
    func should(_ manager: SessionManager, retry request: Request, with error: Error,
                completion: @escaping RequestRetryCompletion) {
        lock.lock() ; defer { lock.unlock() }

        if !isTestingURL {
            self.testURLs().done { (successes) in
                self.lock.lock() ; defer { self.lock.unlock() }
                guard let winner = successes.sorted(by: { (a, b) -> Bool in
                    return a.1.rawValue > b.1.rawValue
                }).first else {
                    completion(false, 0.0)
                    return
                }
                Current.Log.info("Webhook URL update \(self.activeURLType) -> \(winner.1)")
                self.activeURL = winner.0
                self.activeURLType = winner.1
                completion(true, 0.0)
            }.catch { _ in
                completion(false, 0.0)
            }
        }
    }

    private let sessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        return SessionManager(configuration: configuration)
    }()

    private func testURL(_ urlType: WebhookURLType, _ url: URL) -> Promise<(URL, WebhookURLType)?> {
        return Promise { seal in
            Current.Log.verbose("Testing \(urlType) URL")
            let req = self.sessionManager.request(url, method: .post,
                                                  parameters: WebhookRequest(type: "get_config", data: [:]).toJSON(),
                                                  encoding: JSONEncoding.default)
            req.validate().responseJSON { [weak self] response in
                guard let strongSelf = self else { return }
                if response.result.value != nil {
                    strongSelf.isTestingURL = false
                    seal.fulfill((url, urlType))
                    return
                }
                seal.fulfill(nil)
                return
            }
        }
    }

    private func testURLs() -> Promise<[(URL, WebhookURLType)]> {
        isTestingURL = true

        var urls: [WebhookURLType: URL] = [:]

        if self.activeURLType != .internal, let url = self.internalURL {
            urls[.internal] = url
        }
        if self.activeURLType != .cloudhook, let url = self.cloudhookURL {
            urls[.cloudhook] = url
        }
        if self.activeURLType != .remoteUI, let url = self.remoteUIURL {
            urls[.remoteUI] = url
        }
        if self.activeURLType != .external {
            urls[.external] = self.externalURL
        }

        var promises: [Promise<(URL, WebhookURLType)?>] = []

        for (urlType, url) in urls {
            promises.append(testURL(urlType, url))
        }

        return when(fulfilled: promises).compactMapValues { $0 }
    }
}

enum WebhookURLType: Int, CaseIterable {
    case `internal`
    case cloudhook
    case remoteUI
    case external
}
