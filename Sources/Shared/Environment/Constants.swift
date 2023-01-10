import Foundation
import KeychainAccess
import UIKit
import Version

/// Contains shared constants
public enum Constants {
    /// Home Assistant Blue
    public static var tintColor: UIColor {
        #if os(iOS)
        if #available(iOS 13, *) {
            return UIColor { [lighterTintColor, darkerTintColor] (traitCollection: UITraitCollection) -> UIColor in
                traitCollection.userInterfaceStyle == .dark ? lighterTintColor : darkerTintColor
            }
        } else {
            return darkerTintColor
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

    /// The App Group ID used by the app and extensions for sharing data.
    public static var AppGroupID: String {
        "group." + BundleID.lowercased()
    }

    public static var AppGroupContainer: URL {
        let fileManager = FileManager.default

        let groupDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppGroupID)

        guard groupDir != nil else {
            fatalError("Unable to get groupDir.")
        }

        return groupDir!
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

    /// An initialized Keychain from KeychainAccess.
    public static var Keychain: KeychainAccess.Keychain {
        KeychainAccess.Keychain(service: BundleID)
    }

    /// A permanent ID stored in UserDefaults and Keychain.
    public static var PermanentID: String {
        let storageKey = "deviceUID"
        let defaultsStore = UserDefaults(suiteName: Constants.AppGroupID)
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

    internal static var clientVersion: Version {
        // swiftlint:disable:next force_try
        var clientVersion = try! Version(version)
        clientVersion.build = build
        return clientVersion
    }
}

public extension Version {
    static var canSendDeviceID: Version = .init(minor: 104)
    static var pedometerIconsAvailable: Version = .init(minor: 105)
    static var tagWebhookAvailable: Version = .init(minor: 114, prerelease: "b5")
    static var tagPlatformTrigger: Version = .init(minor: 115, prerelease: "any0")
    static var actionSyncing: Version = .init(minor: 115, prerelease: "any0")
    static var localPushConfirm: Version = .init(major: 2021, minor: 10, prerelease: "any0")
    static var externalBusCommandRestart: Version = .init(major: 2021, minor: 12, prerelease: "b6")
    static var updateLocationGPSOptional: Version = .init(major: 2022, minor: 2, prerelease: "any0")
    static var fullWebhookSecretKey: Version = .init(major: 2022, minor: 3)

    var coreRequiredString: String {
        L10n.requiresVersion(String(format: "core-%d.%d", major, minor ?? -1))
    }
}
