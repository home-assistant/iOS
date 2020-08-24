//
//  SettingsStore.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/13/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import KeychainAccess
import CoreLocation
import CoreMotion
import Version
import UIKit

// swiftlint:disable:next type_body_length
public class SettingsStore {
    let keychain = Constants.Keychain
    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    public static let webViewRelatedSettingDidChange: Notification.Name = .init("webViewRelatedSettingDidChange")

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

            do {
                return try JSONDecoder().decode(ConnectionInfo.self, from: unwrappedData)
            } catch let error {
                Current.Log.error("Error when decoding Keychain ConnectionInfo: \(error)")
            }
            return nil
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

    internal var serverVersion: Version {
        // access this publicly using Environment
        let fallback = HomeAssistantAPI.minimumRequiredVersion

        guard let string = prefs.string(forKey: "version") else {
            Current.Log.info("couldn't find version string, falling back")
            return fallback
        }

        do {
            return try Version(hassVersion: string)
        } catch {
            Current.Log.error("couldn't parse version '\(string)': \(error)")
            return fallback
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

    public var integrationDeviceID: String {
        let baseString = Current.device.identifierForVendor() ?? deviceID

        switch Current.appConfiguration {
        case .Beta:
            return "beta_" + baseString
        case .Debug:
            return "debug_" + baseString
        case .FastlaneSnapshot, .Release:
            return baseString
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

    public var overrideDeviceName: String? {
        get {
            return prefs.string(forKey: "override_device_name")
        }
        set {
            prefs.set(newValue, forKey: "override_device_name")
        }
    }

    #if os(iOS)
    public func isLocationEnabled(for state: UIApplication.State) -> Bool {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways:
            return true
        case .authorizedWhenInUse:
            switch state {
            case .active, .inactive:
                return true
            case .background:
                return false
            @unknown default:
                return false
            }
        case .denied, .notDetermined, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    #endif

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

    public struct PageZoom: CaseIterable, Equatable, CustomStringConvertible {
        public let zoom: Int

        internal init?(preference: Int) {
            guard Self.allCases.contains(where: { $0.zoom == preference }) else {
                // in case one of the options causes problems, removing it from allCases will kill it
                Current.Log.info("disregarding zoom preference for \(preference)")
                return nil
            }

            self.zoom = preference
        }

        internal init(_ zoom: IntegerLiteralType) {
            self.zoom = zoom
        }

        public var description: String {
            let zoomString = String(format: "%d%%", zoom)

            if zoom == 100 {
                return L10n.SettingsDetails.General.PageZoom.default(zoomString)
            } else {
                return zoomString
            }
        }

        public var viewScale: String {
            return String(format: "%.02f", CGFloat(zoom) / 100.0)
        }

        public static let `default`: PageZoom = .init(100)

        public static let allCases: [PageZoom] = [
            // similar zooms to Safari, but with nothing above 200%
            .init(50), .init(75), .init(85),
            .init(100), .init(115), .init(125), .init(150), .init(175),
            .init(200)
        ]
    }

    // prior to iOS 12, this didn't work very well in WKWebView
    @available(iOS 12, *)
    public var pageZoom: PageZoom {
        get {
            if let pageZoom = PageZoom(preference: prefs.integer(forKey: "page_zoom")) {
                return pageZoom
            } else {
                return .default
            }
        }
        set {
            prefs.set(newValue.zoom, forKey: "page_zoom")
            NotificationCenter.default.post(name: Self.webViewRelatedSettingDidChange, object: nil)
        }
    }

    public var restoreLastURL: Bool {
        get {
            if let value = prefs.object(forKey: "restoreLastURL") as? NSNumber {
                return value.boolValue
            } else {
                return true
            }
        }
        set {
            prefs.set(newValue, forKey: "restoreLastURL")
        }
    }

    public var periodicUpdateInterval: TimeInterval? {
        get {
            if prefs.object(forKey: "periodicUpdateInterval") == nil {
                return 300.0
            } else {
                let doubleValue = prefs.double(forKey: "periodicUpdateInterval")
                return doubleValue > 0 ? doubleValue : nil
            }
        }
        set {
            if let newValue = newValue {
                precondition(newValue > 0)
                prefs.set(newValue, forKey: "periodicUpdateInterval")
            } else {
                prefs.set(-1, forKey: "periodicUpdateInterval")
            }
        }
    }

    public struct Privacy {
        public var messaging: Bool
        public var crashes: Bool
        public var analytics: Bool

        internal static func key(for keyPath: KeyPath<Privacy, Bool>) -> String {
            switch keyPath {
            case \.messaging: return "messagingEnabled"
            case \.crashes: return "crashesEnabled"
            case \.analytics: return "analyticsEnabled"
            default: return ""
            }
        }
    }

    public var privacy: Privacy {
        get {
            func boolValue(for keyPath: KeyPath<Privacy, Bool>) -> Bool {
                let key = Privacy.key(for: keyPath)
                if prefs.object(forKey: key) == nil {
                    // default to enabled for privacy settings
                    return true
                }
                return prefs.bool(forKey: key)
            }

            return .init(
                messaging: boolValue(for: \.messaging),
                crashes: boolValue(for: \.crashes),
                analytics: boolValue(for: \.analytics)
            )
        }
        set {
            prefs.set(newValue.messaging, forKey: Privacy.key(for: \.messaging))
            prefs.set(newValue.crashes, forKey: Privacy.key(for: \.crashes))
            prefs.set(newValue.analytics, forKey: Privacy.key(for: \.analytics))
            Current.Log.info("privacy updated to \(newValue)")
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
        let baseID = self.removeSpecialCharsFromString(text: Current.device.deviceName())
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
