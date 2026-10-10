import SwiftUI

/// The zoom transition pair, usable from code that still deploys below iOS 18: before it, and on the
/// Mac, which has no zoom transition, both are no-ops and the presentation uses the default transition.
extension View {
    /// Marks this view as what a presentation with the same `id` zooms out of and back into.
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(macOS)
        self
        #else
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
        #endif
    }

    /// Zooms this presented content out of the view marked with `zoomTransitionSource` for `sourceID`.
    @ViewBuilder
    func zoomNavigationTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(macOS)
        self
        #else
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
        #endif
    }
}
