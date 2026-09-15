import Foundation

/// One screen of the dashboard. `sections` is what the home strategy emits for everything with
/// content; `panel` is the single-card layout it falls back to for an empty home or an empty area.
public struct HomeDashboardViewConfig: Identifiable, Equatable, Sendable {
    /// Where the view lives — `"overview"`, `"areas-kitchen"`. Doubles as its identity.
    public let path: String
    public let title: String?
    public let icon: String?
    /// A subview is reached from another view rather than from a tab, and shows a back button.
    public let isSubview: Bool
    public let content: HomeDashboardViewContent
    /// Readings pinned to the top of the view — an area's temperature and humidity.
    public let badges: [HomeEntityBadgeConfig]
    /// The greeting above the sections, when the dashboard greets anybody.
    public let header: HomeDashboardHeaderConfig?
    /// How many columns the web dashboard would use at its widest. Kept because it is what tells the
    /// iPad and the Mac how wide to let the grid grow.
    public let maxColumns: Int

    public var id: String { path }

    public init(
        path: String,
        title: String? = nil,
        icon: String? = nil,
        isSubview: Bool = false,
        content: HomeDashboardViewContent,
        badges: [HomeEntityBadgeConfig] = [],
        header: HomeDashboardHeaderConfig? = nil,
        maxColumns: Int = 3
    ) {
        self.path = path
        self.title = title
        self.icon = icon
        self.isSubview = isSubview
        self.content = content
        self.badges = badges
        self.header = header
        self.maxColumns = maxColumns
    }
}
