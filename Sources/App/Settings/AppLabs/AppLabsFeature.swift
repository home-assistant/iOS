import Foundation
import Shared

enum AppLabsFeature: String, CaseIterable, Identifiable {
    case macNativeSidebar
    case iosNativeTabBar
    case nativeMoreInfo

    var id: String { rawValue }

    // App Labs is limited to TestFlight builds while its features mature.
    static var isLabsAvailable: Bool {
        Current.isTestFlight
    }

    var title: String {
        switch self {
        case .macNativeSidebar: return L10n.Settings.AppLabs.MacNativeSidebar.title
        case .iosNativeTabBar: return L10n.Settings.AppLabs.IosNativeTabBar.title
        case .nativeMoreInfo: return L10n.Settings.AppLabs.NativeMoreInfo.title
        }
    }

    var footer: String {
        switch self {
        case .macNativeSidebar: return L10n.Settings.AppLabs.MacNativeSidebar.footer
        case .iosNativeTabBar: return L10n.Settings.AppLabs.IosNativeTabBar.summary
        case .nativeMoreInfo: return L10n.Settings.AppLabs.NativeMoreInfo.footer
        }
    }

    var isAvailableOnThisDevice: Bool {
        switch self {
        case .macNativeSidebar: return Current.isCatalyst
        case .iosNativeTabBar:
            if #available(iOS 26, *) {
                return !Current.isCatalyst
            }
            return false
        case .nativeMoreInfo:
            // The sheet's chrome is built on iOS 26's navigation subtitle and close button role.
            if #available(iOS 26, *) {
                return !Current.isCatalyst
            }
            return false
        }
    }

    var isEnabled: Bool {
        get {
            isEnabled(in: Current.appLabs.enabledFeatureIds)
        }
        nonmutating set {
            Current.appLabs.setEnabled(newValue, featureId: rawValue)
        }
    }

    /// Resolves against an explicit set of enabled ids, for publishers that emit before the store's
    /// property is updated.
    func isEnabled(in enabledFeatureIds: Set<String>) -> Bool {
        guard Self.isLabsAvailable, isAvailableOnThisDevice else { return false }
        return enabledFeatureIds.contains(rawValue)
    }

    static var availableFeatures: [AppLabsFeature] {
        allCases.filter(\.isAvailableOnThisDevice)
    }
}
