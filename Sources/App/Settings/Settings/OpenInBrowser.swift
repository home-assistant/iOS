import Foundation
import Shared

enum OpenInBrowser: String, CaseIterable {
    case Chrome
    case Firefox
    case FirefoxFocus
    case FirefoxKlar
    case Safari
    case SafariInApp

    var title: String {
        switch self {
        case .Chrome:
            return L10n.SettingsDetails.General.OpenInBrowser.chrome
        case .Firefox:
            return L10n.SettingsDetails.General.OpenInBrowser.firefox
        case .FirefoxFocus:
            return L10n.SettingsDetails.General.OpenInBrowser.firefoxFocus
        case .FirefoxKlar:
            return L10n.SettingsDetails.General.OpenInBrowser.firefoxKlar
        case .Safari:
            return L10n.SettingsDetails.General.OpenInBrowser.default
        case .SafariInApp:
            return L10n.SettingsDetails.General.OpenInBrowser.safariInApp
        }
    }

    var isInstalled: Bool {
        switch self {
        case .Chrome:
            return OpenInChromeController.sharedInstance.isChromeInstalled()
        case .Firefox:
            return OpenInFirefoxControllerSwift().isFirefoxInstalled()
        case .FirefoxFocus:
            return OpenInFirefoxControllerSwift(type: .focus).isFirefoxInstalled()
        case .FirefoxKlar:
            return OpenInFirefoxControllerSwift(type: .klar).isFirefoxInstalled()
        default:
            return true
        }
    }

    var supportsPrivateTabs: Bool {
        switch self {
        case .Firefox:
            return true
        default:
            return false
        }
    }
}
