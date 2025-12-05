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

                        // Extract path from identifier to support both formats
                        // New format: "serverID-path", Old format: "path"
                        let newPath: String
                        if let newId = newPanel.identifier, let serverId = newPanel.serverIdentifier {
                            let prefix = serverId + "-"
                            if newId.hasPrefix(prefix) {
                                newPath = String(newId.dropFirst(prefix.count))
                            } else {
                                newPath = newId
                            }
                        } else {
                            newPath = newPanel.identifier ?? ""
                        }

                        let existingPath: String
                        if let existingId = existingValue.identifier, let serverId = existingValue.serverIdentifier {
                            let prefix = serverId + "-"
                            if existingId.hasPrefix(prefix) {
                                existingPath = String(existingId.dropFirst(prefix.count))
                            } else {
                                existingPath = existingId
                            }
                        } else {
                            existingPath = existingValue.identifier ?? ""
                        }

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
