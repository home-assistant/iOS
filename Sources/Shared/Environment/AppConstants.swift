import Foundation
import KeychainAccess
import UIKit
import Version

/// Contains shared constants
public enum AppConstants {
    public enum WebURLs {
        public static var homeAssistant = URL(string: "https://www.home-assistant.io")!
        public static var homeAssistantGetStarted = URL(string: "https://www.home-assistant.io/installation/")!
        public static var companionAppDocs = URL(string: "https://companion.home-assistant.io")!
        public static var companionAppDocsTroubleshooting =
            URL(string: "https://companion.home-assistant.io/docs/troubleshooting/errors")!
        public static var beta = URL(string: "https://companion.home-assistant.io/app/ios/beta")!
        public static var betaMac = URL(string: "https://companion.home-assistant.io/app/ios/beta_mac")!
        public static var review = URL(string: "https://companion.home-assistant.io/app/ios/review")!
        public static var reviewMac = URL(string: "https://companion.home-assistant.io/app/ios/review_mac")!
        public static var translate = URL(string: "https://companion.home-assistant.io/app/ios/translate")!
        public static var forums = URL(string: "https://community.home-assistant.io/")!
        public static var chat = URL(string: "https://companion.home-assistant.io/app/ios/chat")!
        public static var twitter = URL(string: "https://twitter.com/home_assistant")!
        public static var facebook = URL(string: "https://www.facebook.com/292963007723872")!
        public static var repo = URL(string: "https://companion.home-assistant.io/app/ios/repo")!
        public static var issues = URL(string: "https://companion.home-assistant.io/app/ios/issues")!
    }

    public enum QueryItems: String, CaseIterable {
        case openMoreInfoDialog = "more-info-entity-id"
        case isComingFromAppIntent = "isComingFromAppIntent"
    }

    /// Home Assistant Blue
    public static var tintColor: UIColor {
        #if os(iOS)
        return UIColor { [lighterTintColor, darkerTintColor] (traitCollection: UITraitCollection) -> UIColor in
            traitCollection.userInterfaceStyle == .dark ? lighterTintColor : darkerTintColor
        }
        #else
        return lighterTintColor
        #endif
    }

    public static var lighterTintColor: UIColor {
        UIColor(hue: 199.0 / 360.0, saturation: 0.99, brightness: 0.96, alpha: 1.0)
    }

    public static var darkerTintColor: UIColor {
        UIColor(hue: 199.0 / 360.0, saturation: 0.99, brightness: 0.67, alpha: 1.0)
    }

    /// Help icon UIBarButtonItem
    #if os(iOS)
    public static var helpBarButtonItem: UIBarButtonItem {
        with(UIBarButtonItem(
            icon: .helpCircleOutlineIcon,
            target: nil,
            action: nil
        )) {
            $0.accessibilityLabel = L10n.helpLabel
        }
    }
    #endif

    /// The Bundle ID used for the AppGroupID
    public static var BundleID: String {
        let baseBundleID = Bundle.main.bundleIdentifier!
        var removeBundleSuffix = baseBundleID.replacingOccurrences(of: ".APNSAttachmentService", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".Intents", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".NotificationContentExtension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".TodayWidget", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitapp.watchkitextension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitapp", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".Widgets", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".ShareExtension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".PushProvider", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".Matter", with: "")

        return removeBundleSuffix
    }

    public static var deeplinkURL: URL {
        switch Current.appConfiguration {
        case .debug:
            return URL(string: "homeassistant-dev://")!
        case .beta:
            return URL(string: "homeassistant-beta://")!
        default:
            return URL(string: "homeassistant://")!
        }
    }

    public static func invitationURL(serverURL: URL) -> URL? {
        guard let encodedURLString = serverURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://my.home-assistant.io/invite/#url=\(encodedURLString)")
    }

    public static func navigateDeeplinkURL(
        path: String,
        serverId: String,
        queryParams: String? = nil,
        avoidUnecessaryReload: Bool
    ) -> URL? {
        var url = URL(
            string: "\(AppConstants.deeplinkURL.absoluteString)navigate/\(path)?server=\(serverId)&avoidUnecessaryReload=\(avoidUnecessaryReload)&\(AppConstants.QueryItems.isComingFromAppIntent.rawValue)=true"
        )

        if let queryParams, let newURL = URL(string: "\(url?.absoluteString ?? "")&\(queryParams)") {
            url = newURL
        }

        return url
    }

    public static func openPageDeeplinkURL(path: String, serverId: String) -> URL? {
        AppConstants.navigateDeeplinkURL(path: path, serverId: serverId, avoidUnecessaryReload: true)?
            .withWidgetAuthenticity()
    }

    public static func openEntityDeeplinkURL(entityId: String, serverId: String) -> URL? {
        AppConstants.navigateDeeplinkURL(
            path: "lovelace",
            serverId: serverId,
            queryParams: "\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=\(entityId)",
            avoidUnecessaryReload: true
        )?.withWidgetAuthenticity()
    }

    public static func assistDeeplinkURL(serverId: String, pipelineId: String, startListening: Bool) -> URL? {
        URL(
            string: "\(AppConstants.deeplinkURL.absoluteString)assist?serverId=\(serverId)&pipelineId=\(pipelineId)&startListening=\(startListening)"
        )?.withWidgetAuthenticity()
    }

    /// The App Group ID used by the app and extensions for sharing data.
    public static var AppGroupID: String {
        "group." + BundleID.lowercased()
    }

    public static var AppGroupContainer: URL {
        let fileManager = FileManager.default

        let groupDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID)

        guard let groupDir else {
            fatalError("Unable to get groupDir.")
        }

        return groupDir
    }

    public static var appGRDBFile: URL {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("databases", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create App GRDB file")
            }
        }
        let databaseURL = directoryURL.appendingPathComponent("App.sqlite")
        return databaseURL
    }

    public static var clientEventsFile: URL {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("databases", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create Client Events file")
            }
        }
        let eventsURL = directoryURL.appendingPathComponent("clientEvents.json")
        return eventsURL
    }

    public static var widgetsCacheURL: URL = {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("caches/widgets", isDirectory: true)
        return directoryURL
    }()

    public static func widgetCachedStates(widgetId: String) -> URL {
        let fileManager = FileManager.default
        let directoryURL = Self.widgetsCacheURL
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create Client Events file")
            }
        }
        let eventsURL = directoryURL.appendingPathComponent("/widgetId-\(widgetId).json")
        return eventsURL
    }

    public static var watchMagicItemsInfo: URL {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("caches", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to magic items info file")
            }
        }
        let eventsURL = directoryURL.appendingPathComponent("magicItemsInfo.json")
        return eventsURL
    }

    public static var LogsDirectory: URL {
        let fileManager = FileManager.default
        let directoryURL = AppGroupContainer.appendingPathComponent("logs", isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Error while attempting to create data store URL: \(error)")
            }
        }

        return directoryURL
    }

    public static var DownloadsDirectory: URL {
        let fileManager = FileManager.default
        let directoryURL = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!
            .appendingPathComponent(
                "Downloads",
                isDirectory: true
            )

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Error while attempting to create downloads path URL: \(error)")
            }
        }

        return directoryURL
    }

    /// An initialized Keychain from KeychainAccess.
    public static var Keychain: KeychainAccess.Keychain {
        KeychainAccess.Keychain(service: BundleID)
    }

    /// A permanent ID stored in UserDefaults and Keychain.
    public static var PermanentID: String {
        let storageKey = "deviceUID"
        let defaultsStore = UserDefaults(suiteName: AppConstants.AppGroupID)
        let keychain = KeychainAccess.Keychain(service: storageKey)

        if let keychainUID = keychain[storageKey] {
            return keychainUID
        }

        if let userDefaultsUID = defaultsStore?.object(forKey: storageKey) as? String {
            return userDefaultsUID
        }

        let newID = UUID().uuidString

        if keychain[storageKey] == nil {
            keychain[storageKey] = newID
        }

        if defaultsStore?.object(forKey: storageKey) == nil {
            defaultsStore?.setValue(newID, forKey: storageKey)
        }

        return newID
    }

    public static var build: String {
        SharedPlistFiles.Info.cfBundleVersion
    }

    public static var version: String {
        SharedPlistFiles.Info.cfBundleShortVersionString
    }

    static var clientVersion: Version {
        // swiftlint:disable:next force_try
        var clientVersion = try! Version(version)
        clientVersion.build = build
        return clientVersion
    }
}

public extension Version {
    static let canSendDeviceID: Version = .init(minor: 104)
    static let pedometerIconsAvailable: Version = .init(minor: 105)
    static let tagWebhookAvailable: Version = .init(minor: 114, prerelease: "b5")
    static let actionSyncing: Version = .init(minor: 115, prerelease: "any0")
    static let localPushConfirm: Version = .init(major: 2021, minor: 10, prerelease: "any0")
    static let externalBusCommandRestart: Version = .init(major: 2021, minor: 12, prerelease: "b6")
    static let updateLocationGPSOptional: Version = .init(major: 2022, minor: 2, prerelease: "any0")
    static let fullWebhookSecretKey: Version = .init(major: 2022, minor: 3)
    static let conversationWebhook: Version = .init(major: 2023, minor: 2, prerelease: "any0")
    static let externalBusCommandSidebar: Version = .init(major: 2023, minor: 4, prerelease: "b3")
    static let externalBusCommandAutomationEditor: Version = .init(major: 2024, minor: 2, prerelease: "any0")
    static let canUseAppThemeForStatusBar: Version = .init(major: 2024, minor: 7)
    /// The version where the app can subscribe to entities changes with a filter (e.g. only state changes from sensor
    /// domain)
    static let canSubscribeEntitiesChangesWithFilter: Version = .init(major: 2024, minor: 10)
    /// Allows app to ask frontend to navigate to a specific page
    static let canNavigateThroughFrontend: Version = .init(major: 2025, minor: 6, prerelease: "any0")

    var coreRequiredString: String {
        L10n.requiresVersion(String(format: "core-%d.%d", major, minor ?? -1))
    }
}
