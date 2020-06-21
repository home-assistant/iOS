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

func openURLInBrowser(_ urlToOpen: URL, _ sender: UIViewController) {
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
    case .SafariInApp:
        let sfv = SFSafariViewController(url: urlToOpen)
        sender.present(sfv, animated: true)
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

func showAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message,
                                  preferredStyle: UIAlertController.Style.alert)
    alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
    UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true,
                                                                completion: nil)
}

func setDefaults() {
    if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion"),
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"),
        let stringedShortVersion = shortVersion as? String,
        let stringedBundleVersion = bundleVersion as? String {
        let combined = "\(stringedShortVersion) (\(stringedBundleVersion))"
        prefs.set(stringedBundleVersion, forKey: "lastInstalledBundleVersion")
        prefs.set(stringedShortVersion, forKey: "lastInstalledShortVersion")
        prefs.set(combined, forKey: "lastInstalledVersion")
    }

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

    if prefs.object(forKey: "analyticsEnabled") == nil {
        prefs.setValue(true, forKey: "analyticsEnabled")
    }

    if prefs.object(forKey: "messagingEnabled") == nil {
        prefs.setValue(true, forKey: "messagingEnabled")
    }

    prefs.synchronize()
}

extension UIImage {
    func scaledToSize(_ size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
