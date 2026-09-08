import Foundation
import Shared

extension HAGestureAction {
    /// Whether the action can do anything in the current layout. With the App Labs native tab bar on, the
    /// frontend has no sidebar to show: its pages are the tabs and the More tab.
    var isAvailable: Bool {
        switch self {
        case .showSidebar:
            return !AppLabsFeature.iosNativeTabBar.isEnabled
        default:
            return true
        }
    }
}
