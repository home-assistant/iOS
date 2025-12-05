import PromiseKit
import Shared
import SwiftUI
import WidgetKit

struct WidgetOpenPageEntry: TimelineEntry {
    var date = Date()
    var pages: [IntentPanel] = []
}

struct WidgetOpenPageProvider: IntentTimelineProvider {
    typealias Intent = WidgetOpenPageIntent
    typealias Entry = WidgetOpenPageEntry

    func placeholder(in context: Context) -> WidgetOpenPageEntry {
        let count = WidgetFamilySizes.size(for: context.family)
        let pages = stride(from: 0, to: count, by: 1).map { idx in
            with(IntentPanel(identifier: "redacted\(idx)", display: "Redacted Text")) {
                $0.icon = MaterialDesignIcons.bedEmptyIcon.name
            }
        }

        return .init(pages: pages)
    }

    // Helper function to extract path from identifier, supporting both old and new formats
    // New format: "serverID-path", Old format: "path"
    private func extractPath(from panel: IntentPanel) -> String {
        guard let identifier = panel.identifier else { return "" }
        guard let serverIdentifier = panel.serverIdentifier else { return identifier }

        let prefix = serverIdentifier + "-"
        if identifier.hasPrefix(prefix) {
            return String(identifier.dropFirst(prefix.count))
        } else {
            return identifier
        }
    }

    private func panels(
        for context: Context,
        updating existing: [IntentPanel],
        timeout: Measurement<UnitDuration> = .init(value: 10.0, unit: .seconds),
        completion: @escaping ([IntentPanel]) -> Void
    ) {
        OpenPageIntentHandler.panels { panels in
            var intentsToDisplay = panels

            if !existing.isEmpty {
                intentsToDisplay = existing.compactMap { existingValue in
                    intentsToDisplay.first { newPanel in
                        // Match by server and path, supporting both old and new identifier formats
                        let serversMatch = newPanel.server == existingValue.server
                        let newPath = extractPath(from: newPanel)
                        let existingPath = extractPath(from: existingValue)
                        return serversMatch && newPath == existingPath
                    }
                }
            }
            completion(Array(intentsToDisplay.prefix(WidgetFamilySizes.size(for: context.family))))
        }
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        panels(for: context, updating: configuration.pages ?? []) { panels in
            completion(Entry(pages: Array(panels.prefix(WidgetFamilySizes.sizeForPreview(for: context.family)))))
        }
    }

    private static var expiration: Measurement<UnitDuration> {
        .init(value: 24, unit: .hours)
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        func timeline(for pages: [IntentPanel]) -> Timeline<Entry> {
            .init(
                entries: [.init(pages: pages)],
                policy: .after(Current.date().addingTimeInterval(Self.expiration.converted(to: .seconds).value))
            )
        }
        panels(for: context, updating: configuration.pages ?? []) { panels in
            completion(timeline(for: panels))
        }
    }
}
