import SwiftUI

extension View {
    /// Clears this view's own presentation state whenever an incoming navigation (deep link, universal link,
    /// App Intent or notification tap) needs the frontend on screen. Pair it with every `.sheet`/`.fullScreenCover`
    /// binding that can cover the web frontend, otherwise the navigation happens behind it and looks ignored.
    func dismissesOnAppNavigation(perform dismiss: @escaping () -> Void) -> some View {
        onReceive(AppPresentationDismisser.shared.dismissAllPublisher) { _ in dismiss() }
    }
}
