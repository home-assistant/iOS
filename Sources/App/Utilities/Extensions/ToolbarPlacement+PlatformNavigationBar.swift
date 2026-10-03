import SwiftUI

extension ToolbarPlacement {
    /// The bar a navigation stack draws its title and back button in: the navigation bar on iOS, the
    /// window's toolbar on the Mac.
    static var platformNavigationBar: ToolbarPlacement {
        #if os(macOS)
        return .windowToolbar
        #else
        return .navigationBar
        #endif
    }
}
