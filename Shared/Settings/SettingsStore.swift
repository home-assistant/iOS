//
//  SettingsStore.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/13/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import KeychainAccess
import DeviceKit
import CoreLocation
import CoreMotion

public class SettingsStore {
    let keychain = Constants.Keychain
    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    public var tokenInfo: TokenInfo? {
        get {
            guard let tokenData = ((try? keychain.getData("tokenInfo")) as Data??),
                let unwrappedData = tokenData else {
                return nil
            }

            return try? JSONDecoder().decode(TokenInfo.self, from: unwrappedData)
        }
        set {
            guard let info = newValue else {
                keychain["tokenInfo"] = nil
                return
            }

            do {
                let data = try JSONEncoder().encode(info)
                try keychain.set(data, key: "tokenInfo")
            } catch {
                assertionFailure("Error while saving token info: \(error)")
            }
        }
    }

    public var connectionInfo: ConnectionInfo? {
        get {
            if !self.hasMigratedConnection {
                self.migrateConnectionInfo()
            }
            guard let connectionData = ((try? keychain.getData("connectionInfo")) as Data??),
                let unwrappedData = connectionData else {
                    return nil
            }

            return try? JSONDecoder().decode(ConnectionInfo.self, from: unwrappedData)
        }
        set {
            guard let info = newValue else {
                keychain["connectionInfo"] = nil
                return
            }

            do {
                let data = try JSONEncoder().encode(info)
                try keychain.set(data, key: "connectionInfo")
            } catch {
                assertionFailure("Error while saving token info: \(error)")
            }
        }
    }

    public var authenticatedUser: AuthenticatedUser? {
        get {
            guard let userData = ((try? keychain.getData("authenticatedUser")) as Data??),
                let unwrappedData = userData else {
                    return nil
            }

            return try? JSONDecoder().decode(AuthenticatedUser.self, from: unwrappedData)
        }
        set {
            guard let info = newValue else {
                keychain["authenticatedUser"] = nil
                return
            }

            do {
                let data = try JSONEncoder().encode(info)
                try keychain.set(data, key: "authenticatedUser")
            } catch {
                assertionFailure("Error while saving authenticated user info: \(error)")
            }
        }
    }

    public var pushID: String? {
        get {
          return prefs.string(forKey: "pushID")
        }
        set {
           prefs.setValue(newValue, forKeyPath: "pushID")
        }
    }

    public var deviceID: String {
        get {
            return keychain["deviceID"] ?? self.defaultDeviceID
        }
        set {
            keychain["deviceID"] = newValue
        }
    }

    public var locationEnabled: Bool {
        return CLLocationManager.authorizationStatus() == .authorizedAlways
    }

    public var motionEnabled: Bool {
        return CMPedometer.authorizationStatus() == .authorized
    }

    public var notificationsEnabled: Bool {
        get {
            return prefs.bool(forKey: "notificationsEnabled")
        }
        set {
            prefs.set(newValue, forKey: "messagingEnabled")
            prefs.set(newValue, forKey: "notificationsEnabled")
        }
    }

    public var showAdvancedConnectionSettings: Bool {
        get {
            return prefs.bool(forKey: "showAdvancedConnectionSettings")
        }
        set {
            prefs.set(newValue, forKey: "showAdvancedConnectionSettings")
        }
    }

    public var timezone: String? {
        get {
            return prefs.string(forKey: "time_zone")
        }
        set {
            prefs.setValue(newValue, forKey: "time_zone")
        }
    }

    // MARK: - Private helpers

    private var hasMigratedConnection: Bool {
        get {
            return prefs.bool(forKey: "migratedConnectionInfo")
        }
        set {
            prefs.set(newValue, forKey: "migratedConnectionInfo")
        }
    }

    private var defaultDeviceID: String {
        let baseID = self.removeSpecialCharsFromString(text: Device.current.name ?? "Unknown")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()

        if Current.appConfiguration != .Release {
            return "\(baseID)_\(Current.appConfiguration.description.lowercased())"
        }

        return baseID
    }

    private func removeSpecialCharsFromString(text: String) -> String {
        let okayChars: Set<Character> =
            Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890")
        return String(text.filter {okayChars.contains($0) })
    }

    private func migrateConnectionInfo() {
        if let baseURLString = keychain["baseURL"], let baseURL = URL(string: baseURLString) {
            var internalURL: URL?
            if let internalURLString = keychain["internalBaseURL"],
                let parsedURL = URL(string: internalURLString) {
                internalURL = parsedURL
            }

            var ssids: [String] = []
            if let ssid = keychain["internalBaseURLSSID"] {
                ssids = [ssid]
            }

            self.connectionInfo = ConnectionInfo(externalURL: baseURL, internalURL: internalURL, cloudhookURL: nil,
                                                 remoteUIURL: nil, webhookID: "", webhookSecret: nil,
                                                 internalSSIDs: ssids)
            self.hasMigratedConnection = true
        }

    }
}
