//
//  ConnectionInfo.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/18/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Alamofire
#if os(iOS)
import SystemConfiguration.CaptiveNetwork
#endif

public class ConnectionInfo: Codable {
    public private(set) var externalURL: URL? {
        didSet {
            Current.settingsStore.connectionInfo = self
            guard self.externalURL != nil else { return }
            Current.setUserProperty?("externalURL", "RemoteConnectionMethod")
        }
    }
    public private(set) var internalURL: URL? {
        didSet {
            Current.settingsStore.connectionInfo = self
        }
    }
    public private(set) var remoteUIURL: URL? {
        didSet {
            Current.settingsStore.connectionInfo = self
            guard self.remoteUIURL != nil else { return }
            Current.setUserProperty?("remoteUI", "RemoteConnectionMethod")
        }
    }
    public var webhookID: String {
        didSet {
            Current.settingsStore.connectionInfo = self
        }
    }
    public var webhookSecret: String? {
        didSet {
            Current.settingsStore.connectionInfo = self
        }
    }
    public var cloudhookURL: URL? {
        didSet {
            Current.settingsStore.connectionInfo = self
        }
    }
    public var internalSSIDs: [String]? {
        didSet {
            Current.settingsStore.connectionInfo = self
        }
    }

    public var activeURLType: URLType = .external {
        didSet {
            guard oldValue != self.activeURLType else { return }
            var oldURL: String = "Unknown URL"
            switch oldValue {
            case .internal:
                oldURL = self.internalURL?.absoluteString ?? oldURL
            case .remoteUI:
                oldURL = self.remoteUIURL?.absoluteString ?? oldURL
            case .external:
                oldURL = self.externalURL?.absoluteString ?? oldURL
            }
            Current.Log.verbose("Updated URL from \(oldValue) (\(oldURL)) to \(activeURLType) \(self.activeURL)")
        }
    }

    public init(externalURL: URL?, internalURL: URL?, cloudhookURL: URL?, remoteUIURL: URL?,
                webhookID: String, webhookSecret: String?, internalSSIDs: [String]?) {
        self.externalURL = externalURL
        self.internalURL = internalURL
        self.cloudhookURL = cloudhookURL
        self.remoteUIURL = remoteUIURL
        self.webhookID = webhookID
        self.webhookSecret = webhookSecret
        self.internalSSIDs = internalSSIDs

        if self.internalURL != nil && self.internalSSIDs != nil && self.isOnInternalNetwork {
            self.activeURLType = .internal
        } else if self.externalURL != nil {
            self.activeURLType = .external
        } else if self.remoteUIURL != nil {
            self.activeURLType = .remoteUI
        }
    }

    public enum URLType: Int, Codable, CaseIterable, CustomStringConvertible {
        case `internal`
        case remoteUI
        case external

        public var description: String {
            switch self {
            case .internal:
                return "Internal URL"
            case .remoteUI:
                return "Remote UI"
            case .external:
                return "External URL"
            }
        }
    }

    /// Returns the url that should be used at this moment to access the Home Assistant instance.
    public var activeURL: URL {
        switch self.activeURLType {
        case .internal:
            if let url = self.internalURL {
                guard self.isOnInternalNetwork else {
                    if self.remoteUIURL != nil {
                        self.activeURLType = .remoteUI
                    } else {
                        self.activeURLType = .external
                    }
                    return self.activeURL
                }
                return url
            }
        case .remoteUI:
            if let url = self.remoteUIURL {
                if let internalURL = self.internalURL, self.isOnInternalNetwork {
                    self.activeURLType = .internal
                    return internalURL
                }
                return url
            }
        case .external:
            if let url = self.externalURL {
                if let internalURL = self.internalURL, self.isOnInternalNetwork {
                    self.activeURLType = .internal
                    return internalURL
                }
                return url
            }
        }

        let errMsg = "Unable to get \(self.activeURLType), even though its active!"
        Current.Log.error(errMsg)

        #if os(iOS)
        let alert = UIAlertController(title: "URL Unavailable",
                                      // swiftlint:disable:next line_length
                                      message: "Expected to have a \(self.activeURLType) but none available! Check settings and try again",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Quit App", style: .destructive, handler: { _ in exit(1) }))

        let win = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        win.rootViewController = vc
        win.windowLevel = UIWindow.Level.alert + 1
        win.makeKeyAndVisible()
        vc.present(alert, animated: true, completion: nil)

        #else
        fatalError(errMsg)
        #endif

        return URL(string: "http://somethingbroke.fake")!
    }

    /// Returns the activeURL with /api appended.
    public var activeAPIURL: URL {
        return self.activeURL.appendingPathComponent("api", isDirectory: false)
    }

    public var webhookURL: URL {
        var baseURL: URL = self.activeURL

        if self.activeURLType == .internal {
            baseURL = self.internalURL!
        }
        // FIXME: Re-enable Cloudhook once mobile_app is fixed.
        /* else if let cloudURL = self.cloudhookURL {
            return cloudURL
        }*/

        return baseURL.appendingPathComponent("api/webhook/\(self.webhookID)", isDirectory: false)
    }

    /// Updates the stored address for the given addressType.
    public func setAddress(_ address: URL?, _ addressType: URLType) {
        guard let address = address else { return }
        switch addressType {
        case .internal:
            self.internalURL = address
            if self.isOnInternalNetwork {
                self.activeURLType = .internal
            }
        case .external:
            self.externalURL = address
            self.remoteUIURL = nil
            if self.activeURLType != .internal {
                self.activeURLType = .external
            }
        case .remoteUI:
            self.remoteUIURL = address
            self.externalURL = nil
            if self.activeURLType != .internal {
                self.activeURLType = .remoteUI
            }
        }
    }

    /// Returns true if current SSID is SSID marked for internal URL use.
    public var isOnInternalNetwork: Bool {
        guard let internalSSIDs = self.internalSSIDs, let currentSSID = ConnectionInfo.CurrentWiFiSSID else {
            return false
        }
        return internalSSIDs.contains(currentSSID)
    }

    /// Returns the current SSID if it exists and the platform supports it.
    public static var CurrentWiFiSSID: String? {
        #if os(iOS)
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else { continue }
            return interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
        }
        #endif
        return nil
    }

    /// Returns the current BSSID if it exists and the platform supports it.
    public static var CurrentWiFiBSSID: String? {
        #if os(iOS)
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else { continue }
            return interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
        }
        #endif
        return nil
    }

    /// Rewrites the given URL to ensure that it points to the active API URL.
    public func adaptAPIURL(_ existingURL: URL) -> URL? {
        guard var components = URLComponents(url: existingURL, resolvingAgainstBaseURL: false) else { return nil }

        components.scheme = self.activeURL.scheme
        components.host = self.activeURL.host
        components.port = self.activeURL.port

        return components.url
    }

    /// Check if the provided URL uses the active URL.
    public func ensureURL(_ url: URL, _ apiURL: Bool = false) -> Bool {
        if apiURL {
            return url.scheme == self.activeAPIURL.scheme && url.host == self.activeAPIURL.host &&
                url.port == self.activeAPIURL.port
        }
        return url == self.webhookURL
    }

    // MARK: - RequestAdapter
    public func adapt(_ urlRequest: URLRequest, _ apiURL: Bool = false) throws -> URLRequest {
        guard let currentURL = urlRequest.url else { return urlRequest }

        guard let expectedURL: URL = apiURL ? self.adaptAPIURL(currentURL) : self.webhookURL else { return urlRequest }

        guard currentURL != expectedURL else {
            Current.Log.verbose("No need to change request URL from \(currentURL) to \(expectedURL)")
            return urlRequest
        }

        Current.Log.verbose("Changing request URL from \(currentURL) to \(expectedURL)")

        var urlRequest = urlRequest
        urlRequest.url = expectedURL
        return urlRequest
    }

    // MARK: - RequestRetrier
    public func should(_ manager: SessionManager, retry request: Request, with error: Error) -> Bool {
        // There's only two situations in which we should attempt to change the URL to a point where we may
        // be able to get working again:
        // 1. If remote UI is active and failure is low level (NSURLErrorDomain) which means snitun is down
        // 2. If internal URL is active but SSID doesn't match
        guard let url = request.request?.url else {
            Current.Log.error("Couldn't get URL from request!")
            return false
        }

        let isRemoteUIFailure = self.activeURLType == .remoteUI && url == self.remoteUIURL &&
            (error as NSError).domain == NSURLErrorDomain

        Current.Log.verbose("isRemoteUIFailure \(isRemoteUIFailure)")

        let isInternalURLFailure = self.activeURLType == .internal && url == self.internalURL

        Current.Log.verbose("isInternalURLFailure \(isInternalURLFailure)")

        if isRemoteUIFailure {
            if self.internalURL != nil && self.isOnInternalNetwork {
                self.activeURLType = .internal
            } else if self.externalURL != nil {
                self.activeURLType = .external
            } else {
                return false
            }
            return true
        } else if isInternalURLFailure {
            if self.remoteUIURL != nil {
                self.activeURLType = .remoteUI
            } else if self.externalURL != nil {
                self.activeURLType = .external
            } else {
                return false
            }
            return true
        }

        Current.Log.warning("Not retrying a failure other than remote UI down or internal URL no longer valid")
        return false
    }

    /// Returns if the given URL contains any known URL.
    public func checkURLMatches(_ url: URL) -> Bool {
        let isInternalURL = url.scheme == self.internalURL?.scheme && url.host == self.internalURL?.host &&
            url.port == self.internalURL?.port
        let isExternalURL = url.scheme == self.externalURL?.scheme && url.host == self.externalURL?.host &&
            url.port == self.externalURL?.port
        let isRemoteUIURL = url.scheme == self.remoteUIURL?.scheme && url.host == self.remoteUIURL?.host &&
            url.port == self.remoteUIURL?.port

        return isInternalURL || isExternalURL || isRemoteUIURL
    }

    /// Returns the URLType of the given URL, if it is known.
    public func getURLType(_ url: URL) -> URLType? {
        if url.scheme == self.internalURL?.scheme && url.host == self.internalURL?.host &&
            url.port == self.internalURL?.port {
            return .internal
        } else if url.scheme == self.externalURL?.scheme && url.host == self.externalURL?.host &&
            url.port == self.externalURL?.port {
            return .external
        } else if url.scheme == self.remoteUIURL?.scheme && url.host == self.remoteUIURL?.host &&
            url.port == self.remoteUIURL?.port {
            return .remoteUI
        }

        return nil
    }
}
