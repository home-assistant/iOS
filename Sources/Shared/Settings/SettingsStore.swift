import CoreLocation
import CoreMotion
import Foundation
import KeychainAccess
import UIKit
import Version

public class SettingsStore {
    let keychain = AppConstants.Keychain
    let prefs = UserDefaults(suiteName: AppConstants.AppGroupID)!

    /// These will only be posted on the main thread
    public static let webViewRelatedSettingDidChange: Notification.Name = .init("webViewRelatedSettingDidChange")
    public static let menuRelatedSettingDidChange: Notification.Name = .init("menuRelatedSettingDidChange")
    public static let locationRelatedSettingDidChange: Notification.Name = .init("locationRelatedSettingDidChange")

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
        case .beta:
            return "beta_" + baseString
        case .debug:
            return "debug_" + baseString
        case .fastlaneSnapshot, .release:
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

    #if os(iOS)
    public var matterLastPreferredNetWorkMacExtendedAddress: String? {
        get {
            keychain["matterLastPreferredNetWorkMacExtendedAddress"]
        }
        set {
            keychain["matterLastPreferredNetWorkMacExtendedAddress"] = newValue
        }
    }

    public var matterLastPreferredNetWorkActiveOperationalDataset: String? {
        get {
            keychain["matterLastPreferredNetWorkActiveOperationalDataset"]
        }
        set {
            keychain["matterLastPreferredNetWorkActiveOperationalDataset"] = newValue
        }
    }

    public var matterLastPreferredNetWorkExtendedPANID: String? {
        get {
            keychain["matterLastPreferredNetWorkExtendedPANID"]
        }
        set {
            keychain["matterLastPreferredNetWorkExtendedPANID"] = newValue
        }
    }

    public func isLocationEnabled(for state: UIApplication.State) -> Bool {
        let authorizationStatus: CLAuthorizationStatus

        let locationManager = CLLocationManager()
        authorizationStatus = locationManager.authorizationStatus

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

    public struct PageZoom: CaseIterable, Equatable, CustomStringConvertible, Hashable {
        public let zoom: Int

        init?(preference: Int) {
            guard Self.allCases.contains(where: { $0.zoom == preference }) else {
                // in case one of the options causes problems, removing it from allCases will kill it
                Current.Log.info("disregarding zoom preference for \(preference)")
                return nil
            }

            self.zoom = preference
        }

        init(_ zoom: IntegerLiteralType) {
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

    public var fullScreen: Bool {
        get {
            prefs.bool(forKey: "fullScreen")
        }
        set {
            prefs.set(newValue, forKey: "fullScreen")
            NotificationCenter.default.post(name: Self.webViewRelatedSettingDidChange, object: nil)
        }
    }

    public var edgeToEdge: Bool {
        get {
            prefs.bool(forKey: "edgeToEdge_experimental")
        }
        set {
            prefs.set(newValue, forKey: "edgeToEdge_experimental")
            NotificationCenter.default.post(name: Self.webViewRelatedSettingDidChange, object: nil)
        }
    }

    public var refreshWebViewAfterInactive: Bool {
        get {
            if let value = prefs.object(forKey: "refreshWebViewAfterInactive") as? NSNumber {
                return value.boolValue
            } else {
                return true // Default to ON
            }
        }
        set {
            prefs.set(newValue, forKey: "refreshWebViewAfterInactive")
        }
    }

    public var macNativeFeaturesOnly: Bool {
        get {
            prefs.bool(forKey: "macNativeFeaturesOnly")
        }
        set {
            prefs.set(newValue, forKey: "macNativeFeaturesOnly")
        }
    }

    /// Whether the one-time Live Activity lock screen privacy disclosure has been shown.
    /// Set to true after the first Live Activity is started; never reset.
    public var hasSeenLiveActivityDisclosure: Bool {
        get {
            prefs.bool(forKey: "hasSeenLiveActivityDisclosure")
        }
        set {
            prefs.set(newValue, forKey: "hasSeenLiveActivityDisclosure")
        }
    }

    /// Local push becomes opt-in on 2025.6, users will have local push reset and need to re-enable it
    public var migratedOptInLocalPush: Bool {
        get {
            prefs.bool(forKey: "migratedOptInLocalPush")
        }
        set {
            prefs.set(newValue, forKey: "migratedOptInLocalPush")
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
            if let newValue {
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

        static func key(for keyPath: KeyPath<Privacy, Bool>) -> String {
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

        static func `default`(for keyPath: KeyPath<Privacy, Bool>) -> Bool {
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

        public var title: String {
            switch self {
            case .dock: return L10n.SettingsDetails.General.Visibility.Options.dock
            case .dockAndMenuBar: return L10n.SettingsDetails.General.Visibility.Options.dockAndMenuBar
            case .menuBar: return L10n.SettingsDetails.General.Visibility.Options.menuBar
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

    public var menuItemTemplate: (server: Server, template: String)? {
        get {
            let server: Server?

            if let serverIdentifier = prefs.string(forKey: "menuItemTemplate-server"),
               let configured = Current.servers.server(forServerIdentifier: serverIdentifier) {
                server = configured
            } else {
                // backwards compatibility to before servers, or if the server was deleted
                server = Current.servers.all.first
            }

            if let server {
                return (server, prefs.string(forKey: "menuItemTemplate") ?? "")
            } else {
                return nil
            }
        }
        set {
            prefs.setValue(newValue?.0.identifier.rawValue, forKey: "menuItemTemplate-server")
            prefs.setValue(newValue?.1, forKey: "menuItemTemplate")
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

        static func key(for keyPath: KeyPath<LocationSource, Bool>) -> String {
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

    #if os(iOS)
    public var gestures: [AppGesture: HAGestureAction] {
        get {
            guard let data = prefs.data(forKey: "gesturesSettings"),
                  let decodedGestures = try? JSONDecoder().decode([AppGesture: HAGestureAction].self, from: data) else {
                Current.Log.error("Failed to decode gestures from settings")
                return .defaultGestures
            }
            return decodedGestures
        }
        set {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                prefs.set(encoded, forKey: "gesturesSettings")
            } catch {
                Current.Log.error("Failed to encode gestures for settings, error \(error.localizedDescription)")
            }
        }
    }
    #endif

    // MARK: - Debug settings

    /// Debug options to receive local notifications when something goes wrong
    /// e.g. location update in background fails
    public var receiveDebugNotifications: Bool {
        get {
            prefs.bool(forKey: "receiveDebugNotifications")
        }
        set {
            prefs.set(newValue, forKey: "receiveDebugNotifications")
        }
    }

    /// Debug option to enable toasts handled by the app instead of the web frontend
    public var toastsHandledByApp: Bool {
        get {
            prefs.bool(forKey: "toastsHandledByApp")
        }
        set {
            prefs.set(newValue, forKey: "toastsHandledByApp")
        }
    }

    public var carPlayAssistDebugSettings: CarPlayAssistDebugSettings {
        get {
            let defaults = CarPlayAssistDebugSettings.default
            return CarPlayAssistDebugSettings(
                audioCategory: carPlayAssistEnum(
                    key: "carPlayAssistAudioCategory",
                    default: defaults.audioCategory
                ),
                audioMode: carPlayAssistEnum(
                    key: "carPlayAssistAudioMode",
                    default: defaults.audioMode
                ),
                preferredSampleRate: carPlayAssistEnum(
                    key: "carPlayAssistPreferredSampleRate",
                    default: defaults.preferredSampleRate
                ),
                allowBluetoothHFP: carPlayAssistBool(
                    key: "carPlayAssistAllowBluetoothHFP",
                    default: defaults.allowBluetoothHFP
                ),
                allowBluetoothA2DP: carPlayAssistBool(
                    key: "carPlayAssistAllowBluetoothA2DP",
                    default: defaults.allowBluetoothA2DP
                ),
                duckOthers: carPlayAssistBool(
                    key: "carPlayAssistDuckOthers",
                    default: defaults.duckOthers
                ),
                interruptSpokenAudio: carPlayAssistBool(
                    key: "carPlayAssistInterruptSpokenAudio",
                    default: defaults.interruptSpokenAudio
                ),
                playRecordingIndicatorTone: carPlayAssistBool(
                    key: "carPlayAssistPlayRecordingIndicatorTone",
                    default: defaults.playRecordingIndicatorTone
                ),
                recorderManagesAudioSession: carPlayAssistBool(
                    key: "carPlayAssistRecorderManagesAudioSession",
                    default: defaults.recorderManagesAudioSession
                ),
                ttsPlaybackStrategy: carPlayAssistEnum(
                    key: "carPlayAssistTTSPlaybackStrategy",
                    default: defaults.ttsPlaybackStrategy
                ),
                ttsReconfigureAudioSession: carPlayAssistBool(
                    key: "carPlayAssistTTSReconfigureAudioSession",
                    default: defaults.ttsReconfigureAudioSession
                ),
                ttsDeactivateBeforeReconfigure: carPlayAssistBool(
                    key: "carPlayAssistTTSDeactivateBeforeReconfigure",
                    default: defaults.ttsDeactivateBeforeReconfigure
                ),
                ttsActivateAudioSession: carPlayAssistBool(
                    key: "carPlayAssistTTSActivateAudioSession",
                    default: defaults.ttsActivateAudioSession
                ),
                ttsCategory: carPlayAssistEnum(
                    key: "carPlayAssistTTSCategory",
                    default: defaults.ttsCategory
                ),
                ttsMode: carPlayAssistEnum(
                    key: "carPlayAssistTTSMode",
                    default: defaults.ttsMode
                ),
                ttsAllowBluetoothHFP: carPlayAssistBool(
                    key: "carPlayAssistTTSAllowBluetoothHFP",
                    default: defaults.ttsAllowBluetoothHFP
                ),
                ttsAllowBluetoothA2DP: carPlayAssistBool(
                    key: "carPlayAssistTTSAllowBluetoothA2DP",
                    default: defaults.ttsAllowBluetoothA2DP
                ),
                ttsDuckOthers: carPlayAssistBool(
                    key: "carPlayAssistTTSDuckOthers",
                    default: defaults.ttsDuckOthers
                ),
                ttsInterruptSpokenAudio: carPlayAssistBool(
                    key: "carPlayAssistTTSInterruptSpokenAudio",
                    default: defaults.ttsInterruptSpokenAudio
                ),
                avPlayerAutomaticallyWaitsToMinimizeStalling: carPlayAssistBool(
                    key: "carPlayAssistAVPlayerAutomaticallyWaitsToMinimizeStalling",
                    default: defaults.avPlayerAutomaticallyWaitsToMinimizeStalling
                ),
                ttsPlaybackDelay: carPlayAssistEnum(
                    key: "carPlayAssistTTSPlaybackDelay",
                    default: defaults.ttsPlaybackDelay
                )
            )
        }
        set {
            prefs.set(newValue.audioCategory.rawValue, forKey: "carPlayAssistAudioCategory")
            prefs.set(newValue.audioMode.rawValue, forKey: "carPlayAssistAudioMode")
            prefs.set(newValue.preferredSampleRate.rawValue, forKey: "carPlayAssistPreferredSampleRate")
            prefs.set(newValue.allowBluetoothHFP, forKey: "carPlayAssistAllowBluetoothHFP")
            prefs.set(newValue.allowBluetoothA2DP, forKey: "carPlayAssistAllowBluetoothA2DP")
            prefs.set(newValue.duckOthers, forKey: "carPlayAssistDuckOthers")
            prefs.set(newValue.interruptSpokenAudio, forKey: "carPlayAssistInterruptSpokenAudio")
            prefs.set(newValue.playRecordingIndicatorTone, forKey: "carPlayAssistPlayRecordingIndicatorTone")
            prefs.set(newValue.recorderManagesAudioSession, forKey: "carPlayAssistRecorderManagesAudioSession")
            prefs.set(newValue.ttsPlaybackStrategy.rawValue, forKey: "carPlayAssistTTSPlaybackStrategy")
            prefs.set(newValue.ttsReconfigureAudioSession, forKey: "carPlayAssistTTSReconfigureAudioSession")
            prefs.set(newValue.ttsDeactivateBeforeReconfigure, forKey: "carPlayAssistTTSDeactivateBeforeReconfigure")
            prefs.set(newValue.ttsActivateAudioSession, forKey: "carPlayAssistTTSActivateAudioSession")
            prefs.set(newValue.ttsCategory.rawValue, forKey: "carPlayAssistTTSCategory")
            prefs.set(newValue.ttsMode.rawValue, forKey: "carPlayAssistTTSMode")
            prefs.set(newValue.ttsAllowBluetoothHFP, forKey: "carPlayAssistTTSAllowBluetoothHFP")
            prefs.set(newValue.ttsAllowBluetoothA2DP, forKey: "carPlayAssistTTSAllowBluetoothA2DP")
            prefs.set(newValue.ttsDuckOthers, forKey: "carPlayAssistTTSDuckOthers")
            prefs.set(newValue.ttsInterruptSpokenAudio, forKey: "carPlayAssistTTSInterruptSpokenAudio")
            prefs.set(
                newValue.avPlayerAutomaticallyWaitsToMinimizeStalling,
                forKey: "carPlayAssistAVPlayerAutomaticallyWaitsToMinimizeStalling"
            )
            prefs.set(newValue.ttsPlaybackDelay.rawValue, forKey: "carPlayAssistTTSPlaybackDelay")
        }
    }

    public func resetCarPlayAssistDebugSettings() {
        carPlayAssistDebugSettings = .default
    }

    // MARK: - Private helpers

    private func carPlayAssistBool(key: String, default defaultValue: Bool) -> Bool {
        guard prefs.object(forKey: key) != nil else {
            return defaultValue
        }
        return prefs.bool(forKey: key)
    }

    private func carPlayAssistEnum<T: RawRepresentable>(key: String, default defaultValue: T) -> T
        where T.RawValue == String {
        guard let rawValue = prefs.string(forKey: key),
              let value = T(rawValue: rawValue) else {
            return defaultValue
        }
        return value
    }

    private func carPlayAssistEnum<T: RawRepresentable>(key: String, default defaultValue: T) -> T
        where T.RawValue == Int {
        guard prefs.object(forKey: key) != nil else {
            return defaultValue
        }
        return T(rawValue: prefs.integer(forKey: key)) ?? defaultValue
    }

    private var defaultDeviceID: String {
        let baseID = removeSpecialCharsFromString(text: Current.device.deviceName())
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()

        if Current.appConfiguration != .release {
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
