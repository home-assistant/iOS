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
    private var webhookID: String
    private var externalURL: URL
    private var internalURLRaw: URL?
    private var internalSSIDs: [String]?
    private var internalURL: URL? {
        guard internalURLRaw != nil && internalSSIDs != nil && ConnectionInfo.CurrentWiFiSSID != nil else {
            return nil
        }
        return internalURLRaw
    }
    private var remoteUIURL: URL?
    private var cloudhookURL: URL?

    public var activeURLType: WebhookURLType = .external {
        didSet {
            guard oldValue != self.activeURLType else { return }
            var oldURL: String = "Unknown URL"
            switch oldValue {
            case .internal:
                oldURL = self.internalURL?.absoluteString ?? oldURL
            case .cloudhook:
                oldURL = self.cloudhookURL?.absoluteString ?? oldURL
            case .remoteUI:
                oldURL = self.remoteUIURL?.absoluteString ?? oldURL
            case .external:
                oldURL = self.externalURL.absoluteString
            }
            Current.Log.verbose("Updated URL from \(oldValue) (\(oldURL)) to \(activeURLType) \(self.activeURL)")
        }
    }

    private var activeURL: URL {
        switch self.activeURLType {
        case .internal:
            guard let url = self.internalURL else {
                Current.Log.warning("Unable to get \(self.activeURLType), returning external!")
                return self.externalURL
            }
            return url
        case .cloudhook:
            guard let url = self.cloudhookURL else {
                Current.Log.warning("Unable to get \(self.activeURLType), returning external!")
                return self.externalURL
            }
            return url
        case .remoteUI:
            guard let url = self.remoteUIURL else {
                Current.Log.warning("Unable to get \(self.activeURLType), returning external!")
                return self.externalURL
            }
            return url
        case .external:
            return self.externalURL
        }
    }

    // MARK: - Initialization

    public init(webhookID: String, connectionInfo: ConnectionInfo, remoteUIURL: URL?, cloudhookURL: URL?) {
        self.webhookID = webhookID
        let path = "api/webhook/\(self.webhookID)"
        self.externalURL = connectionInfo.externalBaseURL.appendingPathComponent(path, isDirectory: false)

        if let cloudhookURL = cloudhookURL {
            self.cloudhookURL = cloudhookURL
            self.activeURLType = .cloudhook
        }

        if let remoteURL = remoteUIURL {
            self.remoteUIURL = remoteURL.appendingPathComponent(path, isDirectory: false)
            self.activeURLType = .remoteUI
        }

        if let url = connectionInfo.internalBaseURL, let ssids = connectionInfo.internalSSIDs {
            self.internalURLRaw = url.appendingPathComponent(path, isDirectory: false)
            self.internalSSIDs = ssids
            self.activeURLType = .internal
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
    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let currentURL = urlRequest.url else { return urlRequest }

        guard currentURL != self.activeURL else {
            Current.Log.verbose("No need to change request URL from \(currentURL) to \(self.activeURL)")
            return urlRequest
        }

        Current.Log.verbose("Changing request URL from \(currentURL) to \(self.activeURL)")

        var urlRequest = urlRequest
        urlRequest.url = self.activeURL
        return urlRequest
    }

    // MARK: - RequestRetrier
    public func should(_ manager: SessionManager, retry request: Request, with error: Error,
                       completion: @escaping RequestRetryCompletion) {
        // There's only two situations in which we should attempt to change the URL to a point where we may
        // be able to get working again:
        // 1. If remote UI is active and failure is low level (NSURLErrorDomain) which means snitun is down
        // 2. If internal URL is active but SSID doesn't match
        guard let url = request.request?.url else {
            Current.Log.error("Couldn't get URL from request!")
            completion(false, 0.0)
            return
        }

        let isRemoteUIFailure = url == self.remoteUIURL && (error as NSError).domain == NSURLErrorDomain

        let isInternalURLFailure = url == self.internalURLRaw

        if isRemoteUIFailure {
            if self.internalURL != nil {
                self.activeURLType = .internal
            } else {
                self.activeURLType = .external
            }
            completion(true, 0.0)
        } else if isInternalURLFailure {
            if self.cloudhookURL != nil {
                self.activeURLType = .cloudhook
            } else if self.remoteUIURL != nil {
                self.activeURLType = .remoteUI
            } else {
                self.activeURLType = .external
            }
            completion(true, 0.0)
        } else {
            Current.Log.warning("Not retrying a failure other than remote UI down or internal URL no longer valid")
            completion(false, 0.0)
            return
        }

    }
}

public enum WebhookURLType: Int, CaseIterable, CustomStringConvertible {
    case `internal`
    case cloudhook
    case remoteUI
    case external

    public var description: String {
        switch self {
        case .internal:
            return "Internal URL"
        case .cloudhook:
            return "Cloudhook"
        case .remoteUI:
            return "Remote UI"
        case .external:
            return "External URL"
        }
    }
}
