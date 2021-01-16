//
//  Constants.swift
//  Shared
//
//  Created by Stephan Vanterpool on 6/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import KeychainAccess
import Version

/// Contains shared constants
public struct Constants {
    /// Home Assistant Blue
    public static var tintColor: UIColor {
        let light = UIColor(hue: 199.0/360.0, saturation: 0.99, brightness: 0.96, alpha: 1.0)
        let dark = UIColor(hue: 199.0/360.0, saturation: 0.99, brightness: 0.67, alpha: 1.0)

        #if os(iOS)
        if #available(iOS 13, *) {
            return UIColor { (traitCollection: UITraitCollection) -> UIColor in
                return traitCollection.userInterfaceStyle == .dark ? light : dark
            }
        } else {
            return dark
        }
        #else
        return light
        #endif
    }

    /// Help icon UIBarButtonItem
    #if os(iOS)
    public static var helpBarButtonItem: UIBarButtonItem {
        let icon = MaterialDesignIcons.helpCircleOutlineIcon.image(ofSize: CGSize(width: 30, height: 30), color: .blue)
        return UIBarButtonItem(image: icon, style: .plain, target: nil, action: nil)
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

        return removeBundleSuffix
    }

    /// The App Group ID used by the app and extensions for sharing data.
    public static var AppGroupID: String {
        return "group." + self.BundleID.lowercased()
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
        let directoryURL = self.AppGroupContainer.appendingPathComponent("logs", isDirectory: true)

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
        return KeychainAccess.Keychain(service: self.BundleID)
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

    static public var build: String {
        SharedPlistFiles.Info.cfBundleVersion
    }

    static public var version: String {
        SharedPlistFiles.Info.cfBundleShortVersionString
    }

    static internal var clientVersion: Version {
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
}
