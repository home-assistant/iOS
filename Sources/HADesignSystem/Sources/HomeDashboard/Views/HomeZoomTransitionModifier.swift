#if !os(watchOS)
import SwiftUI

/// The pushed screen's half of the zoom transition, applied where the system has one.
///
/// Its own modifier because `navigationTransition` is iOS 18 and up: written inline, the
/// availability check would have to wrap the whole screen and both branches would need to stay in
/// step.
public struct HomeZoomTransitionModifier: ViewModifier {
    private let id: String
    private let namespace: Namespace.ID

    public init(id: String, namespace: Namespace.ID) {
        self.id = id
        self.namespace = namespace
    }

    public func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

/// The card's half of the same transition: the thing the screen grows out of.
public struct HomeZoomSourceModifier: ViewModifier {
    private let id: String
    private let namespace: Namespace.ID

    public init(id: String, namespace: Namespace.ID) {
        self.id = id
        self.namespace = namespace
    }

    public func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}
#endif
