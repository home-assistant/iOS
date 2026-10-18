import Foundation
import Shared
import WidgetKit

/// One rendering of the Areas widget: the page of areas it is showing and what a tap on one opens.
struct WidgetAreasEntry: TimelineEntry {
    var date: Date
    var page: WidgetAreasPage
    /// How many pages there are to step through, which is what the arrows are drawn from.
    var pageCount: Int
    var serverId: String?
    var serverName: String?
    /// The dashboard an area's view lives on for this server, `nil` on a server that has none. See
    /// `AppPanel.areasDashboardPath(serverId:)`.
    var dashboardPath: String?

    static func empty(date: Date = Current.date()) -> WidgetAreasEntry {
        .init(
            date: date,
            page: .init(id: 0, sections: []),
            pageCount: 0,
            serverId: nil,
            serverName: nil,
            dashboardPath: nil
        )
    }

    /// A sample home, for the previews and the widget gallery. See ``WidgetAreasSampleData``.
    static func preview(family: WidgetFamily, page: Int = 0) -> WidgetAreasEntry {
        let pages = WidgetAreasLayout.pages(sections: WidgetAreasSampleData.sections, family: family)
        return .init(
            date: Current.date(),
            page: pages.indices.contains(page) ? pages[page] : .init(id: 0, sections: []),
            pageCount: pages.count,
            serverId: nil,
            serverName: "Home",
            dashboardPath: "home"
        )
    }
}
