import Foundation
import Shared

enum AppLabsFeature: String, CaseIterable, Identifiable {
    case macNativeSidebar

    var id: String { rawValue }

    // App Labs is limited to TestFlight builds while its features mature.
    static var isLabsAvailable: Bool {
        Current.isTestFlight
    }

    var title: String {
        switch self {
        case .macNativeSidebar: return L10n.Settings.AppLabs.MacNativeSidebar.title
        }
    }

    var footer: String {
        switch self {
        case .macNativeSidebar: return L10n.Settings.AppLabs.MacNativeSidebar.footer
        }
    }

    var isAvailableOnThisDevice: Bool {
        switch self {
        case .macNativeSidebar: return Current.isCatalyst
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
