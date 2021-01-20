//
//  Utils.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import KeychainAccess
import Shared
import RealmSwift
import SafariServices
import Version

func resetStores() {
    do {
        try keychain.removeAll()
    } catch {
        Current.Log.error("Error when trying to delete everything from Keychain!")
    }

    if let groupDefaults = UserDefaults(suiteName: Constants.AppGroupID) {
        for key in groupDefaults.dictionaryRepresentation().keys {
            groupDefaults.removeObject(forKey: key)
        }
        groupDefaults.synchronize()
    }

    Realm.reset()
}

func openURLInBrowser(_ urlToOpen: URL, _ sender: UIViewController?) {
    guard ["http", "https"].contains(urlToOpen.scheme?.lowercased()) else {
        UIApplication.shared.open(urlToOpen, options: [:], completionHandler: nil)
        return
    }

    let browserPreference = prefs.string(forKey: "openInBrowser")
        .flatMap { OpenInBrowser(rawValue: $0) } ?? .Safari

    switch browserPreference {
    case .Chrome where OpenInChromeController.sharedInstance.isChromeInstalled():
        OpenInChromeController.sharedInstance.openInChrome(urlToOpen, callbackURL: nil)
    case .Firefox where OpenInFirefoxControllerSwift().isFirefoxInstalled():
        OpenInFirefoxControllerSwift().openInFirefox(urlToOpen)
    case .SafariInApp where sender != nil:
        let sfv = SFSafariViewController(url: urlToOpen)
        sender!.present(sfv, animated: true)
    default:
        UIApplication.shared.open(urlToOpen, options: [:], completionHandler: nil)
    }
}

func convertToDictionary(text: String) -> [String: Any]? {
    if let data = text.data(using: .utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            Current.Log.error("Error converting JSON string to dict: \(error)")
        }
    }
    return nil
}

func setDefaults() {
    // before we reset the value, read in the last version number -- if it's pre-team migration, save that
    if let previous = prefs.string(forKey: "lastInstalledShortVersion"),
        let version = try? Version(hassVersion: previous),
        version <= Version(major: 2020, minor: 4, patch: 1),
        Current.settingsStore.connectionInfo == nil {
        Current.Log.info("going to show migration message")
        prefs.set(true, forKey: "onboardingShouldShowMigrationMessage")
    }

    prefs.set(Constants.build, forKey: "lastInstalledBundleVersion")
    prefs.set(Constants.version, forKey: "lastInstalledShortVersion")

    if prefs.object(forKey: "openInBrowser") == nil {
        if prefs.bool(forKey: "openInChrome") {
            prefs.set(OpenInBrowser.Chrome.rawValue, forKey: "openInBrowser")
            prefs.removeObject(forKey: "openInChrome")
        } else {
            prefs.set(OpenInBrowser.Safari.rawValue, forKey: "openInBrowser")
        }
    }

    if prefs.object(forKey: "confirmBeforeOpeningUrl") == nil {
        prefs.setValue(true, forKey: "confirmBeforeOpeningUrl")
    }

    if prefs.object(forKey: "locationUpdateOnZone") == nil {
        prefs.set(true, forKey: "locationUpdateOnZone")
    }

    if prefs.object(forKey: "locationUpdateOnBackgroundFetch") == nil {
        prefs.set(true, forKey: "locationUpdateOnBackgroundFetch")
    }

    if prefs.object(forKey: "locationUpdateOnSignificant") == nil {
        prefs.set(true, forKey: "locationUpdateOnSignificant")
    }

    if prefs.object(forKey: "locationUpdateOnNotification") == nil {
        prefs.set(true, forKey: "locationUpdateOnNotification")
    }

    prefs.synchronize()
}

extension UIImage {
    func scaledToSize(_ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(
            size: size,
            format: with(UIGraphicsImageRendererFormat.preferred()) {
                $0.opaque = imageRendererFormat.opaque
            }
        ).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
