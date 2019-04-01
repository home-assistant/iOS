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

    public var cloudhookID: String? {
        get {
            return keychain["cloudhook_id"]
        }
        set {
            keychain["cloudhook_id"] = newValue
        }
    }

    public var cloudhookURL: String? {
        get {
            return keychain["cloudhook_url"]
        }
        set {
            keychain["cloudhook_url"] = newValue
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
        if let cloudURLStr = Current.settingsStore.cloudhookURL {
            return URL(string: cloudURLStr)
        }

        guard let wID = Current.settingsStore.webhookID,
            let url = Current.settingsStore.connectionInfo?.activeAPIURL else {
                Current.Log.error("Unable to build webhook URL!")

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
        let baseID = self.removeSpecialCharsFromString(text: Device().name)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()

        if Current.appConfiguration != .Release {
            return baseID+"_"+Current.appConfiguration.description.lowercased()
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
            let basicAuthKeychain = Keychain(server: baseURLString, protocolType: .https,
                                             authenticationType: .httpBasic)
            let credentials: ConnectionInfo.BasicAuthCredentials?
            if let username = basicAuthKeychain["basicAuthUsername"],
                let password = basicAuthKeychain["basicAuthPassword"] {
                credentials = ConnectionInfo.BasicAuthCredentials(username: username, password: password)
            } else {
                credentials = nil
            }

            var internalURL: URL?
            if let internalURLString = keychain["internalBaseURL"],
                let parsedURL = URL(string: internalURLString) {
                internalURL = parsedURL
            }

            let info = ConnectionInfo(baseURL: baseURL,
                                      internalBaseURL: internalURL,
                                      internalSSID: keychain["internalBaseURLSSID"],
                                      basicAuthCredentials: credentials)
            self.connectionInfo = info
            self.hasMigratedConnection = true
        }

    }
}
