import Foundation
import GRDB
import KeychainAccess
import SafariServices
import Security
import Shared

private enum DeleteKeychainError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .keychain(status):
            "Keychain error: \(status)"
        }
    }
}

func resetStores() {
    do {
        try keychain.removeAll()
    } catch {
        Current.Log.error("Error when trying to delete everything from Keychain!")
    }

    let bundleId = Bundle.main.bundleIdentifier!
    UserDefaults.standard.removePersistentDomain(forName: bundleId)
    UserDefaults.standard.removePersistentDomain(forName: AppConstants.AppGroupID)

    do {
        try Current.database().write { db in
            _ = try AppZone.deleteAll(db)
            _ = try NotificationCategory.deleteAll(db)
            _ = try WatchComplication.deleteAll(db)
            _ = try LocationHistoryEntry.deleteAll(db)
            _ = try LocationError.deleteAll(db)
        }
    } catch {
        Current.Log.error("Failed to reset database: \(error)")
    }

    // Clearing the app group defaults above also clears the Realm→GRDB
    // migration flag, so drop the legacy store too or the importer would
    // repopulate GRDB from it on the next launch.
    RealmToGRDBMigration.deleteLegacyStore()
}

func deleteKeychainCompletely() throws {
    let keychainClasses: [CFString] = [
        kSecClassGenericPassword,
        kSecClassInternetPassword,
        kSecClassCertificate,
        kSecClassKey,
        kSecClassIdentity,
    ]

    for keychainClass in keychainClasses {
        let status = SecItemDelete([kSecClass as String: keychainClass] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeleteKeychainError.keychain(status)
        }
    }

    UserDefaults(suiteName: AppConstants.AppGroupID)?.removeObject(forKey: "deviceUID")
    // Do not mark servers as deleted here. We want the sanitized GRDB mirror to
    // survive the forced restart so startup can recover the server list.
}

func openURLInBrowser(_ urlToOpen: URL, _ sender: UIViewController?) {
    guard ["http", "https"].contains(urlToOpen.scheme?.lowercased()) else {
        URLOpener.shared.open(urlToOpen, options: [:], completionHandler: nil)
        return
    }

    let browserPreference = prefs.string(forKey: "openInBrowser")
        .flatMap { OpenInBrowser(rawValue: $0) } ?? .Safari
    let privateTabPreference = prefs.bool(forKey: "openInPrivateTab")

    switch browserPreference {
    case .Chrome where OpenInChromeController.sharedInstance.isChromeInstalled():
        OpenInChromeController.sharedInstance.openInChrome(urlToOpen, callbackURL: nil)
    case .Firefox where OpenInFirefoxControllerSwift().isFirefoxInstalled():
        OpenInFirefoxControllerSwift().openInFirefox(urlToOpen, privateTab: privateTabPreference)
    case .FirefoxFocus where OpenInFirefoxControllerSwift(type: .focus).isFirefoxInstalled():
        OpenInFirefoxControllerSwift(type: .focus).openInFirefox(urlToOpen)
    case .FirefoxKlar where OpenInFirefoxControllerSwift(type: .klar).isFirefoxInstalled():
        OpenInFirefoxControllerSwift(type: .klar).openInFirefox(urlToOpen)
    case .SafariInApp where sender != nil:
        let sfv = SFSafariViewController(url: urlToOpen)
        sender!.present(sfv, animated: true)
    default:
        URLOpener.shared.open(urlToOpen, options: [:], completionHandler: nil)
    }
}

func convertToDictionary(text: String) -> [String: Any]? {
    if let data = text.data(using: .utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            Current.Log.error("Error converting JSON string to dict: \(error)")
        }
    }
    return nil
}

func setDefaults() {
    prefs.set(AppConstants.build, forKey: "lastInstalledBundleVersion")
    prefs.set(AppConstants.version, forKey: "lastInstalledShortVersion")

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
}
