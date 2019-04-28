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
        get {
            return prefs.bool(forKey: "locationEnabled")
        }
        set {
            prefs.set(newValue, forKey: "locationEnabled")
        }
    }

    public var motionEnabled: Bool {
        get {
            return prefs.bool(forKey: "motionEnabled")
        }
        set {
            prefs.set(newValue, forKey: "motionEnabled")
        }
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

    public var cloudhookURL: URL? {
        get {
            guard let val = keychain["cloudhook_url"] else {
                return nil
            }
            return URL(string: val)
        }
        set {
            keychain["cloudhook_url"] = newValue?.absoluteString
        }
    }

    public var remoteUIURL: URL? {
        get {
            guard let val = keychain["remote_ui_url"] else {
                return nil
            }
            return URL(string: val)
        }
        set {
            keychain["remote_ui_url"] = newValue?.absoluteString
        }
    }

    public var webhookID: String? {
        get {
            return keychain["webhook_id"]
        }
        set {
            keychain["webhook_id"] = newValue
        }
    }

    public var webhookSecret: String? {
        get {
            return keychain["webhook_secret"]
        }
        set {
            keychain["webhook_secret"] = newValue
        }
    }

    public var webhookURL: URL? {
        if let cloudhookURL = Current.settingsStore.cloudhookURL {
            return cloudhookURL
        }

        guard let wID = Current.settingsStore.webhookID else {
            Current.Log.error("Unable to get webhook ID during URL build!")

            return nil
        }

        guard let url = Current.settingsStore.connectionInfo?.activeAPIURL else {
            Current.Log.error("Unable to get active API URL during URL build!")

            return nil
        }

        return url.appendingPathComponent("webhook/\(wID)")
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

            var info = ConnectionInfo(baseURL: baseURL, internalBaseURL: internalURL, internalSSIDs: nil)
            if let ssid = keychain["internalBaseURLSSID"] {
                info = ConnectionInfo(baseURL: baseURL, internalBaseURL: internalURL, internalSSIDs: [ssid])
            }

            self.connectionInfo = info
            self.hasMigratedConnection = true
        }

    }
}
