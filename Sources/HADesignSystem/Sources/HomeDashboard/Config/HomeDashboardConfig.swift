import Foundation

/// A whole generated dashboard: the overview, one view per area, and the extra views the strategy
/// adds. The Swift counterpart of the frontend's `LovelaceConfig` as the home strategy produces it.
public struct HomeDashboardConfig: Equatable, Sendable {
    public let views: [HomeDashboardViewConfig]

    public init(views: [HomeDashboardViewConfig]) {
        self.views = views
    }

    /// The dashboard's first view, the one the panel opens on.
    public var overview: HomeDashboardViewConfig? {
        views.first
    }

    public func view(path: String) -> HomeDashboardViewConfig? {
        views.first { $0.path == path }
    }
}
