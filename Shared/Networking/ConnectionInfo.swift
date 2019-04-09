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
    }

    public let baseURL: URL
    public let internalBaseURL: URL?
    public let internalSSID: String?
    public let basicAuthCredentials: BasicAuthCredentials?

    public init(baseURL: URL, internalBaseURL: URL?, internalSSID: String?,
                basicAuthCredentials: BasicAuthCredentials?) {
        self.baseURL = baseURL
        self.internalBaseURL = internalBaseURL
        self.internalSSID = internalSSID
        self.basicAuthCredentials = basicAuthCredentials
    }

    /// Returns the url that should be used at this moment to access the home assistant instance.
    public var activeURL: URL {
        #if os(iOS)
        if let internalSSID = self.internalSSID, internalSSID == ConnectionInfo.currentSSID(),
            let internalBaseURL = self.internalBaseURL {
            return internalBaseURL
        }
        #endif
        /*if let remoteUIURL = Current.settingsStore.remoteUIURL {
            return remoteUIURL
        }*/
        return self.baseURL
    }

    public var activeAPIURL: URL {
        return self.activeURL.appendingPathComponent("api", isDirectory: false)
    }
}

#if os(iOS)
public extension ConnectionInfo {
    static func currentSSID() -> String? {
        var ssid: String?
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                // swiftlint:disable:next force_cast
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                    ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
                    break
                }
            }
        }
        return ssid
    }

    static func currentBSSID() -> String? {
        var ssid: String?
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                // swiftlint:disable:next force_cast
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                    ssid = interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
                    break
                }
            }
        }
        return ssid
    }
}
#endif
