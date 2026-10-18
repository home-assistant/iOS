import AppIntents
import Foundation
import Shared
import WidgetKit

/// Builds the Areas widget's timeline out of the areas the app has already stored for the server,
/// so the widget needs no connection of its own — the app's database is the same one the areas
/// screen and the watch read.
@available(iOS 17, *)
struct WidgetAreasTimelineProvider: WidgetSingleEntryTimelineProvider {
    typealias Entry = WidgetAreasEntry
    typealias Intent = WidgetAreasAppIntent

    /// Areas and floors change about as often as the home is rearranged, so the widget spends its
    /// refresh budget rarely and picks changes up from the app's next sync.
    var expiration: Measurement<UnitDuration> {
        .init(value: 60, unit: .minutes)
    }

    func makePlaceholder(in context: Context) -> WidgetAreasEntry {
        .empty()
    }

    func makePreviewEntry(in context: Context) -> WidgetAreasEntry {
        .preview(family: context.family)
    }

    func makeSnapshotEntry(for configuration: WidgetAreasAppIntent, in context: Context) async -> WidgetAreasEntry {
        entry(for: configuration, family: context.family)
    }

    func makeTimelineEntry(for configuration: WidgetAreasAppIntent, in context: Context) async -> WidgetAreasEntry {
        entry(for: configuration, family: context.family)
    }

    /// The page of areas the widget draws, for the family asking for it.
    ///
    /// Takes the family rather than the timeline context, which cannot be made outside WidgetKit,
    /// so everything but the four lines above it can be tested.
    func entry(for configuration: WidgetAreasAppIntent, family: WidgetFamily) -> WidgetAreasEntry {
        // Only the server the widget was configured with: falling back to another one would show
        // someone else's rooms, and open them, under a name the widget never mentioned.
        guard let server = configuration.server.getServer() else {
            Current.Log.info("No server found for areas widget, returning empty entry")
            return .empty()
        }
        let serverId = server.identifier.rawValue
        let areas: [AppArea]
        do {
            areas = try AppArea.fetchAreas(for: serverId)
        } catch {
            Current.Log.error("Failed to fetch areas for areas widget: \(error.localizedDescription)")
            areas = []
        }

        let sections = WidgetAreaSections.make(areas: areas, otherAreasTitle: L10n.Widgets.Areas.otherAreas)
        let pages = WidgetAreasLayout.pages(sections: sections, family: family)
        let page = WidgetAreasPageStore.clamp(
            WidgetAreasPageStore.page(serverId: serverId, family: family),
            pageCount: pages.count
        )

        return .init(
            date: Current.date(),
            page: pages.indices.contains(page) ? pages[page] : .init(id: 0, sections: []),
            pageCount: pages.count,
            serverId: serverId,
            serverName: server.info.name,
            dashboardPath: AppPanel.areasDashboardPath(serverId: serverId)
        )
    }
}
