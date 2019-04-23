//
//  ConnectionInfo.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/18/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
#if os(iOS)
import SystemConfiguration.CaptiveNetwork
#endif

public struct ConnectionInfo: Codable {
    public struct BasicAuthCredentials: Codable {
        public let username: String
        public let password: String
        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }

        public var urlCredential: URLCredential {
            return URLCredential(user: self.username, password: self.password, persistence: .synchronizable)
        }
    }

    public let externalBaseURL: URL
    public let internalBaseURL: URL?
    public let internalSSIDs: [String]?
    public let basicAuthCredentials: BasicAuthCredentials?

    public init(baseURL: URL, internalBaseURL: URL?, internalSSIDs: [String]?,
                basicAuthCredentials: BasicAuthCredentials?) {
        self.externalBaseURL = baseURL
        self.internalBaseURL = internalBaseURL
        self.internalSSIDs = internalSSIDs
        self.basicAuthCredentials = basicAuthCredentials
    }

    /// Returns the url that should be used at this moment to access the home assistant instance.
    public var activeURL: URL {
        if let internalBaseURL = self.internalBaseURL, self.isOnInternalNetwork {
            return internalBaseURL
        }
        /*if let remoteUIURL = Current.settingsStore.remoteUIURL {
            return remoteUIURL
        }*/
        return self.externalBaseURL
    }

    public var activeAPIURL: URL {
        return self.activeURL.appendingPathComponent("api", isDirectory: false)
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
}
