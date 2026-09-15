#if !os(watchOS)
import SwiftUI

public extension View {
    /// Hands a screen everything its cards read: the dashboard's context and the drag in progress.
    ///
    /// Applied to each screen rather than once around the navigation stack, because a
    /// `navigationDestination`'s content is built outside the modifiers wrapped around the stack —
    /// an `@EnvironmentObject` injected there never reaches a pushed screen, and reading one that is
    /// not there is a crash rather than a fallback.
    func homeDashboardEnvironment(
        context: HomeDashboardContext,
        reorder: HomeAreaReorderCoordinator
    ) -> some View {
        environment(\.homeDashboard, context)
            .environmentObject(reorder)
    }
}
#endif
