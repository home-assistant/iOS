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
