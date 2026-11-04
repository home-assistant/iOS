#if os(iOS) && !targetEnvironment(macCatalyst)
import SwiftUI

extension EnvironmentValues {
    /// `isDynamicIslandLimitedInWidth` for every OS the extension supports. Before iOS 27 the system
    /// did not report it, so the island is treated as full width there.
    var haIsDynamicIslandLimitedInWidth: Bool {
        guard #available(iOS 27.0, *) else { return false }
        return isDynamicIslandLimitedInWidth
    }
}
#endif
