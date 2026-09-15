#if !os(watchOS)
import SwiftUI

/// The frontend's colour names — `"red"`, `"amber"`, `"blue-grey"` — resolved against its own theme,
/// so a badge the strategy asked to be red is the same red the web dashboard draws.
public enum HomeDashboardNamedColor {
    public static func color(_ name: String?) -> Color? {
        guard let name, !name.isEmpty else {
            return nil
        }
        return FrontendColors(rawValue: "--\(name)-color")?.color
    }
}
#endif
