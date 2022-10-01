import Foundation
import KeychainAccess
import RealmSwift
import SafariServices
import Shared
import Version

func resetStores() {
    do {
        try keychain.removeAll()
    } catch {
        Current.Log.error("Error when trying to delete everything from Keychain!")
    }

    let bundleId = Bundle.main.bundleIdentifier!
    UserDefaults.standard.removePersistentDomain(forName: bundleId)
    UserDefaults.standard.removePersistentDomain(forName: Constants.AppGroupID)

    Realm.reset()
}

func openURLInBrowser(_ urlToOpen: URL, _ sender: UIViewController?) {
    guard ["http", "https"].contains(urlToOpen.scheme?.lowercased()) else {
        UIApplication.shared.open(urlToOpen, options: [:], completionHandler: nil)
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
