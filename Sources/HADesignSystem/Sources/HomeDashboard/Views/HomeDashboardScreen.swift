#if !os(watchOS)
import SwiftUI

/// The whole native home: the overview, and a room's screen a tap away.
///
/// The card the user tapped grows into the screen it opens — `navigationTransition(.zoom)`, which is
/// the system's own way of saying "this screen came from that card". It needs iOS 18; before that the
/// push is the usual one.
public struct HomeDashboardScreen: View {
    @Namespace private var zoomNamespace
    @State private var path: [String] = []
    @StateObject private var reorder: HomeAreaReorderCoordinator

    private let dashboard: HomeDashboardConfig
    private let context: HomeDashboardContext

    /// - Parameters:
    ///   - dashboard: What ``HomeDashboardStrategy`` generated for this server.
    ///   - context: The states, the copy and where taps go.
    ///   - onReorderAreas: Called with the new order when a room is dragged somewhere else. Rooms
    ///     cannot be dragged at all without it.
    public init(
        dashboard: HomeDashboardConfig,
        context: HomeDashboardContext,
        onReorderAreas: @escaping ([String]) -> Void = { _ in }
    ) {
        self.dashboard = dashboard
        self.context = context
        _reorder = StateObject(wrappedValue: HomeAreaReorderCoordinator(onReorder: onReorderAreas))
    }

    public var body: some View {
        NavigationStack(path: $path) {
            overview
                .homeDashboardEnvironment(context: navigatingContext, reorder: reorder)
                .navigationDestination(for: String.self) { path in
                    // Injected again here on purpose: see `homeDashboardEnvironment`.
                    areaPage(path: path)
                        .homeDashboardEnvironment(context: navigatingContext, reorder: reorder)
                }
        }
    }

    @ViewBuilder private var overview: some View {
        if let overview = dashboard.overview {
            HomeDashboardPage(config: overview, areaOrder: areaOrder)
                .navigationTitle(overview.title ?? "")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func areaPage(path: String) -> some View {
        if let view = dashboard.view(path: path) {
            HomeDashboardPage(config: view)
                .navigationTitle(view.title ?? "")
                .modifier(HomeZoomTransitionModifier(id: path, namespace: zoomNamespace))
        }
    }

    /// The rooms in the order they were generated in, which is the registry's.
    private var areaOrder: [String] {
        dashboard.views.compactMap { HomeDashboardPath.areaId(from: $0.path) }
    }

    /// The context the cards get: the one handed in, with navigation to another view of this
    /// dashboard taken care of here rather than by the app.
    private var navigatingContext: HomeDashboardContext {
        var navigating = context
        navigating.zoomNamespace = zoomNamespace
        navigating.perform = { action in
            if case let .navigate(destination) = action, dashboard.view(path: destination) != nil {
                path.append(destination)
                return
            }
            context.perform(action)
        }
        return navigating
    }
}

#Preview {
    let registry = HomeDashboardSampleHome.registry
    return HomeDashboardScreen(
        dashboard: HomeDashboardStrategy.generate(config: HomeDashboardSampleHome.strategyConfig, registry: registry),
        context: HomeDashboardContext(registry: registry)
    )
}
#endif
