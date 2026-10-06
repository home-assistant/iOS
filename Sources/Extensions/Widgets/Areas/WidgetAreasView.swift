import Foundation
import Shared
import SwiftUI
import WidgetKit

/// The Areas widget: the design system draws the floors, the area tiles and the paging arrows; this
/// adds the deep link each tile opens and the intents the arrows run.
@available(iOS 17, *)
struct WidgetAreasView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: WidgetAreasEntry

    var body: some View {
        if entry.page.sections.isEmpty {
            WidgetEmptyStateView(message: L10n.Widgets.Areas.Empty.description)
                .widgetBackground(Color.widgetPrimaryBackground)
        } else {
            WidgetAreasContentView(
                page: entry.page,
                pageCount: entry.pageCount,
                family: widgetFamily,
                serverName: entry.serverName,
                strings: .init(
                    previousPage: L10n.Widgets.Areas.previousPage,
                    nextPage: L10n.Widgets.Areas.nextPage
                ),
                areaContent: { area, tile in
                    guard let serverId = entry.serverId,
                          let url = AppConstants.openAreaDeeplinkURL(
                              areaId: area.areaId,
                              serverId: serverId,
                              dashboardPath: entry.dashboardPath
                          ) else {
                        return tile
                    }
                    // Without `.plain` the link tints the whole tile with the accent colour, which
                    // paints over the area's own icon colour.
                    return AnyView(
                        Link(destination: url) {
                            tile
                        }
                        .buttonStyle(.plain)
                    )
                },
                previousControl: { arrow in pageControl(step: -1, arrow: arrow) },
                nextControl: { arrow in pageControl(step: 1, arrow: arrow) }
            )
            // A tap that misses a tile opens the dashboard the areas live on. The small family has
            // no per-tile links at all — WidgetKit only honours this one there — so it is also what
            // a tap anywhere but the arrows does on a small widget.
            .widgetURL(dashboardURL)
        }
    }

    private var dashboardURL: URL? {
        guard let serverId = entry.serverId, let dashboardPath = entry.dashboardPath else { return nil }
        return AppConstants.openPageDeeplinkURL(path: dashboardPath, serverId: serverId)
    }

    /// One arrow, wrapped in the intent that turns the page. A widget with no server has no page to
    /// turn to either, so the arrow is left inert rather than running an intent that would do
    /// nothing.
    private func pageControl(step: Int, arrow: AnyView) -> AnyView {
        guard let serverId = entry.serverId else { return arrow }
        let intent = WidgetAreasPageAppIntent()
        intent.serverId = serverId
        intent.familyRawValue = widgetFamily.rawValue
        intent.step = step
        intent.pageCount = entry.pageCount
        return AnyView(
            Button(intent: intent) {
                arrow
            }
            .buttonStyle(.plain)
        )
    }
}

@available(iOS 17, *)
#Preview {
    WidgetAreasView(entry: .preview(family: .systemMedium))
        .frame(width: 338, height: 158)
}
