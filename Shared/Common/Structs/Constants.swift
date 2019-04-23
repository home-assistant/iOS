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

/// Contains shared constants
public struct Constants {
    /// Home Assistant Blue
    public static var blue: UIColor {
        return UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)
    }

    /// The Bundle ID used for the AppGroupID
    public static var BundleID: String {
        let baseBundleID = Bundle.main.bundleIdentifier!
        var removeBundleSuffix = baseBundleID.replacingOccurrences(of: ".APNSAttachmentService", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".Intents", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".NotificationContentExtension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".TodayWidget", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitapp.watchkitextension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitapp", with: "")

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
}
