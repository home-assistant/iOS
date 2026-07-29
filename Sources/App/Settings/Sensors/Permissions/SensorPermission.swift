import Foundation
import SFSafeSymbols
import Shared

/// A device permission that some of the app sensors depend on, listed in `SensorPermissionsView`.
enum SensorPermission: String, CaseIterable, Identifiable {
    case motion
    case focus
    #if os(iOS) && !targetEnvironment(macCatalyst)
    case health
    #endif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .motion:
            return L10n.SettingsDetails.Location.MotionPermission.title
        case .focus:
            return L10n.SettingsSensors.FocusPermission.title
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .health:
            return L10n.SettingsSensors.Health.header
        #endif
        }
    }

    /// Whether a permission that was already answered can be changed from the app's page in
    /// system settings. Apple Health isn't there — its switches live in the Health app — so
    /// tapping it asks HealthKit again instead, which is what surfaces the sensors enabled since
    /// the last request.
    var isChangedInSystemSettings: Bool {
        switch self {
        case .motion, .focus:
            return true
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .health:
            return false
        #endif
        }
    }

    var symbol: SFSymbol {
        switch self {
        case .motion:
            return .figureWalk
        case .focus:
            return .moon
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .health:
            return .heart
        #endif
        }
    }
}
