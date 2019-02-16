//
//  Constants.swift
//  Shared
//
//  Created by Stephan Vanterpool on 6/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
#if os(iOS)
import KeychainAccess
#endif

/// Contains shared constants
public struct Constants {
    /// The Bundle ID used for the AppGroupID
    public static var BundleID: String {
        let baseBundleID = Bundle.main.bundleIdentifier!
        var removeBundleSuffix = baseBundleID.replacingOccurrences(of: ".watchkitapp", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitextension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".TodayWidget", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".Intents", with: "")

        return removeBundleSuffix
    }

    /// The App Group ID used by the app and extensions for sharing data.
    public static var AppGroupID: String {
        return "group." + self.BundleID.lowercased()
    }

    #if os(iOS)
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
    #endif
}
