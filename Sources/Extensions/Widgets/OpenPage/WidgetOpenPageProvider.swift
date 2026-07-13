import AppIntents
import Shared
import SwiftUI
import WidgetKit

struct WidgetOpenPageEntry: TimelineEntry {
    var date = Date()
    var pages: [PageAppEntity] = []
}

@available(iOS 17.0, *)
struct WidgetOpenPageProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetOpenPageEntry
    typealias Intent = WidgetOpenPageAppIntent

    func placeholder(in context: Context) -> WidgetOpenPageEntry {
        let count = WidgetFamilySizes.size(for: context.family)
        let pages = stride(from: 0, to: count, by: 1).map { idx in
            PageAppEntity(
                id: "redacted\(idx)",
                panel: .init(
                    icon: MaterialDesignIcons.bedEmptyIcon.name,
                    title: "Redacted Text",
                    path: "redacted\(idx)",
                    component: "",
                    showInSidebar: true
                ),
                serverId: ""
            )
        }

        return .init(pages: pages)
    }

    private func panels(for context: Context, updating existing: [PageAppEntity]) -> [PageAppEntity] {
        var available: [PageAppEntity] = []
        do {
            available = try AppPanel.panelsPerServer().flatMap { server, panels in
                panels.map { panel in
                    PageAppEntity(
                        id: "\(server.identifier.rawValue)-\(panel.path)",
                        panel: .init(
                            icon: panel.icon,
                            title: panel.title,
                            path: panel.path,
                            component: panel.component,
                            showInSidebar: panel.showInSidebar
                        ),
                        serverId: server.identifier.rawValue
                    )
                }
            }
        } catch {
            Current.Log.error("Widget error fetching panels: \(error)")
        }

        var pagesToDisplay = available
        if !existing.isEmpty {
            // Refresh the configured pages against the latest panel data, keeping the user's order
            pagesToDisplay = existing.compactMap { existingPage in
                available.first { newPage in
                    newPage.serverId == existingPage.serverId && newPage.panel.path == existingPage.panel.path
                } ?? existingPage
            }
        }
        return Array(pagesToDisplay.prefix(WidgetFamilySizes.size(for: context.family)))
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        let pages = panels(for: context, updating: configuration.pages ?? [])
        return Entry(pages: Array(pages.prefix(WidgetFamilySizes.sizeForPreview(for: context.family))))
    }

    private static var expiration: Measurement<UnitDuration> {
        .init(value: 24, unit: .hours)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let pages = panels(for: context, updating: configuration.pages ?? [])
        return Timeline(
            entries: [.init(pages: pages)],
            policy: .after(Current.date().addingTimeInterval(Self.expiration.converted(to: .seconds).value))
        )
    }
}
