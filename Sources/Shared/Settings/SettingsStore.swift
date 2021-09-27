import CoreLocation
import CoreMotion
import Foundation
import KeychainAccess
import UIKit
import Version

public class SettingsStore {
    let keychain = Constants.Keychain
    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!

    /// These will only be posted on the main thread
    public static let webViewRelatedSettingDidChange: Notification.Name = .init("webViewRelatedSettingDidChange")
    public static let menuRelatedSettingDidChange: Notification.Name = .init("menuRelatedSettingDidChange")
    public static let locationRelatedSettingDidChange: Notification.Name = .init("locationRelatedSettingDidChange")
    /// This may be posted on any thread
    public static let connectionInfoDidChange: Notification.Name = .init("connectionInfoDidChange")

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

    private var cachedConnectionInfo: ConnectionInfo?
    public var connectionInfo: ConnectionInfo? {
        get {
            if let cachedConnectionInfo = cachedConnectionInfo {
                return cachedConnectionInfo
            }

            if NSClassFromString("XCTest") != nil {
                return nil
            }

            guard let connectionData = ((try? keychain.getData("connectionInfo")) as Data??),
                  let unwrappedData = connectionData else {
                return nil
            }

            do {
                return try JSONDecoder().decode(ConnectionInfo.self, from: unwrappedData)
            } catch {
                Current.Log.error("Error when decoding Keychain ConnectionInfo: \(error)")
            }
            return nil
        }
        set {
            cachedConnectionInfo = newValue

            if NSClassFromString("XCTest") != nil {
                return
            }

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

            NotificationCenter.default.post(
                name: Self.connectionInfoDidChange,
                object: nil,
                userInfo: nil
            )
        }
    }

    internal var serverVersion: Version? {
        // access this publicly using Environment
        guard let string = prefs.string(forKey: "version") else {
            Current.Log.info("couldn't find version string, falling back")
            return nil
        }

        do {
            return try Version(hassVersion: string)
        } catch {
            Current.Log.error("couldn't parse version '\(string)': \(error)")
            return nil
        }
    }

    public var pushID: String? {
        get {
            prefs.string(forKey: "pushID")
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
            keychain["deviceID"] ?? defaultDeviceID
        }
        set {
            keychain["deviceID"] = newValue
        }
    }

    public var overrideDeviceName: String? {
        get {
            prefs.string(forKey: "override_device_name")
        }
        set {
            prefs.set(newValue, forKey: "override_device_name")
        }
    }

    #if os(iOS)
    public func isLocationEnabled(for state: UIApplication.State) -> Bool {
        let authorizationStatus: CLAuthorizationStatus

        if #available(iOS 14, *) {
            let locationManager = CLLocationManager()
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }

        switch authorizationStatus {
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
            prefs.bool(forKey: "showAdvancedConnectionSettings")
        }
        set {
            prefs.set(newValue, forKey: "showAdvancedConnectionSettings")
        }
    }

    public var timezone: String? {
        get {
            prefs.string(forKey: "time_zone")
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

        public var viewScaleValue: String {
            String(format: "%.02f", CGFloat(zoom) / 100.0)
        }

        public static let `default`: PageZoom = .init(100)

        public static let allCases: [PageZoom] = [
            // similar zooms to Safari, but with nothing above 200%
            .init(50), .init(75), .init(85),
            .init(100), .init(115), .init(125), .init(150), .init(175),
            .init(200),
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
            precondition(Thread.isMainThread)
            prefs.set(newValue.zoom, forKey: "page_zoom")
            NotificationCenter.default.post(name: Self.webViewRelatedSettingDidChange, object: nil)
        }
    }

    public var pinchToZoom: Bool {
        get {
            prefs.bool(forKey: "pinchToZoom")
        }
        set {
            prefs.set(newValue, forKey: "pinchToZoom")
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
        public var alerts: Bool
        public var updates: Bool
        public var updatesIncludeBetas: Bool

        internal static func key(for keyPath: KeyPath<Privacy, Bool>) -> String {
            switch keyPath {
            case \.messaging: return "messagingEnabled"
            case \.crashes: return "crashesEnabled"
            case \.analytics: return "analyticsEnabled"
            case \.alerts: return "alertsEnabled"
            case \.updates: return "updateCheckingEnabled"
            case \.updatesIncludeBetas: return "updatesIncludeBetas"
            default: return ""
            }
        }

        internal static func `default`(for keyPath: KeyPath<Privacy, Bool>) -> Bool {
            switch keyPath {
            case \.messaging: return true
            case \.crashes: return false
            case \.analytics: return false
            case \.alerts: return true
            case \.updates: return true
            case \.updatesIncludeBetas: return true
            default: return false
            }
        }
    }

    public var privacy: Privacy {
        get {
            func boolValue(for keyPath: KeyPath<Privacy, Bool>) -> Bool {
                let key = Privacy.key(for: keyPath)
                if prefs.object(forKey: key) == nil {
                    // value never set, use the default for this one
                    return Privacy.default(for: keyPath)
                }
                return prefs.bool(forKey: key)
            }

            return .init(
                messaging: boolValue(for: \.messaging),
                crashes: boolValue(for: \.crashes),
                analytics: boolValue(for: \.analytics),
                alerts: boolValue(for: \.alerts),
                updates: boolValue(for: \.updates),
                updatesIncludeBetas: boolValue(for: \.updatesIncludeBetas)
            )
        }
        set {
            prefs.set(newValue.messaging, forKey: Privacy.key(for: \.messaging))
            prefs.set(newValue.crashes, forKey: Privacy.key(for: \.crashes))
            prefs.set(newValue.analytics, forKey: Privacy.key(for: \.analytics))
            prefs.set(newValue.alerts, forKey: Privacy.key(for: \.alerts))
            prefs.set(newValue.updates, forKey: Privacy.key(for: \.updates))
            prefs.set(newValue.updatesIncludeBetas, forKey: Privacy.key(for: \.updatesIncludeBetas))
            Current.Log.info("privacy updated to \(newValue)")
        }
    }

    public enum LocationVisibility: String, CaseIterable {
        case dock
        case dockAndMenuBar
        case menuBar

        public var isStatusItemVisible: Bool {
            switch self {
            case .dockAndMenuBar, .menuBar: return true
            case .dock: return false
            }
        }

        public var isDockVisible: Bool {
            switch self {
            case .dockAndMenuBar, .dock: return true
            case .menuBar: return false
            }
        }
    }

    public var locationVisibility: LocationVisibility {
        get {
            prefs.string(forKey: "locationVisibility").flatMap(LocationVisibility.init(rawValue:)) ?? .dock
        }
        set {
            prefs.set(newValue.rawValue, forKey: "locationVisibility")
            NotificationCenter.default.post(
                name: Self.menuRelatedSettingDidChange,
                object: nil,
                userInfo: nil
            )
        }
    }

    public var menuItemTemplate: String {
        get {
            prefs.string(forKey: "menuItemTemplate") ?? ""
        }
        set {
            prefs.setValue(newValue, forKey: "menuItemTemplate")
            NotificationCenter.default.post(
                name: Self.menuRelatedSettingDidChange,
                object: nil,
                userInfo: nil
            )
        }
    }

    public struct LocationSource {
        public var zone: Bool
        public var backgroundFetch: Bool
        public var significantLocationChange: Bool
        public var pushNotifications: Bool

        internal static func key(for keyPath: KeyPath<LocationSource, Bool>) -> String {
            switch keyPath {
            case \.zone: return "locationUpdateOnZone"
            case \.backgroundFetch: return "locationUpdateOnBackgroundFetch"
            case \.significantLocationChange: return "locationUpdateOnSignificant"
            case \.pushNotifications: return "locationUpdateOnNotification"
            default: return ""
            }
        }
    }

    public var locationSources: LocationSource {
        get {
            func boolValue(for keyPath: KeyPath<LocationSource, Bool>) -> Bool {
                let key = LocationSource.key(for: keyPath)
                if prefs.object(forKey: key) == nil {
                    // default to enabled for location source settings
                    return true
                }
                return prefs.bool(forKey: key)
            }

            return .init(
                zone: boolValue(for: \.zone),
                backgroundFetch: boolValue(for: \.backgroundFetch),
                significantLocationChange: boolValue(for: \.significantLocationChange),
                pushNotifications: boolValue(for: \.pushNotifications)
            )
        }
        set {
            prefs.set(newValue.zone, forKey: LocationSource.key(for: \.zone))
            prefs.set(newValue.backgroundFetch, forKey: LocationSource.key(for: \.backgroundFetch))
            prefs.set(newValue.significantLocationChange, forKey: LocationSource.key(for: \.significantLocationChange))
            prefs.set(newValue.pushNotifications, forKey: LocationSource.key(for: \.pushNotifications))
            Current.Log.info("location sources updated to \(newValue)")
            NotificationCenter.default.post(name: Self.locationRelatedSettingDidChange, object: nil)
        }
    }

    public var clearBadgeAutomatically: Bool {
        get {
            if let value = prefs.object(forKey: "clearBadgeAutomatically") as? NSNumber {
                return value.boolValue
            } else {
                return true
            }
        }
        set {
            prefs.set(newValue, forKey: "clearBadgeAutomatically")
        }
    }

    public var widgetAuthenticityToken: String {
        let key = "widgetAuthenticityToken"

        if let existing = prefs.string(forKey: key) {
            return existing
        } else {
            let string = UUID().uuidString
            prefs.set(string, forKey: key)
            return string
        }
    }

    // MARK: - Private helpers

    private var defaultDeviceID: String {
        let baseID = removeSpecialCharsFromString(text: Current.device.deviceName())
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
        return String(text.filter { okayChars.contains($0) })
    }
}
