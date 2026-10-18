import Shared
import SwiftUI

private struct WatchNativeNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(false)
            .modify { view in
                if #available(watchOS 11.0, *) {
                    view.toolbarVisibility(.visible, for: .navigationBar)
                } else {
                    view.toolbar(.visible, for: .navigationBar)
                }
            }
    }
}

extension View {
    /// Asks for the system navigation bar — the title, the back chevron, and the edge swipe that
    /// comes with them — on a screen pushed inside the watch home's `NavigationStack`.
    ///
    /// The stack's root hides its own bar so it can draw the home header instead. From watchOS 26
    /// on, that choice applies to the root alone and pushed screens get their bar back by
    /// themselves; before it, they inherit the hidden bar and come up with no way back at all, so
    /// every pushed screen has to state the visibility it wants rather than assume the default.
    func watchNativeNavigationBar() -> some View {
        modifier(WatchNativeNavigationBarModifier())
    }
}
