#if !os(watchOS)
import SwiftUI

/// What every card in a dashboard needs and none of them should be handed one at a time: the current
/// states, the copy, how to draw an entity and what to do when one is tapped.
///
/// Carried in the environment rather than passed down: a section holds cards, a card holds badges,
/// and threading four values through all of it would be the whole of this renderer.
public struct HomeDashboardContext {
    public var registry: HomeRegistry
    public var strings: HomeDashboardStrings
    public var presenter: HomeEntityPresenter
    /// Where a tap goes. Navigating and calling services are the app's business, not the renderer's.
    public var perform: (HomeDashboardAction) -> Void
    /// The namespace the zoom transition matches a room's card against the screen it opens in. `nil`
    /// outside a navigation stack — in a preview, a snapshot or the gallery.
    public var zoomNamespace: Namespace.ID?

    public init(
        registry: HomeRegistry,
        strings: HomeDashboardStrings = .preview,
        presenter: HomeEntityPresenter = .preview,
        perform: @escaping (HomeDashboardAction) -> Void = { _ in },
        zoomNamespace: Namespace.ID? = nil
    ) {
        self.registry = registry
        self.strings = strings
        self.presenter = presenter
        self.perform = perform
        self.zoomNamespace = zoomNamespace
    }

    /// How an entity should be drawn right now, or `nil` when it has no state to draw.
    public func presentation(of entityId: String) -> HomeEntityPresentation? {
        registry.state(entityId).map { presenter($0, in: registry) }
    }
}

private struct HomeDashboardContextKey: EnvironmentKey {
    static let defaultValue = HomeDashboardContext(registry: HomeRegistry())
}

public extension EnvironmentValues {
    /// The dashboard the cards in this subtree belong to.
    var homeDashboard: HomeDashboardContext {
        get { self[HomeDashboardContextKey.self] }
        set { self[HomeDashboardContextKey.self] = newValue }
    }
}
#endif
