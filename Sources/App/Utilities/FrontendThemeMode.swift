import Foundation
import UIKit

/// The "Theme mode" a Home Assistant user picks in their frontend profile, stored per account.
enum FrontendThemeMode: String {
    case automatic
    case light
    case dark

    /// Reads the `dark` flag out of the `theme` frontend user data; anything else follows the device.
    init(userDataValue: Any?) {
        guard let settings = userDataValue as? [String: Any], let dark = settings["dark"] as? Bool else {
            self = .automatic
            return
        }
        self = dark ? .dark : .light
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .automatic: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}
