import Shared
import SwiftUI
import WidgetKit
import PromiseKit

struct WidgetOpenPageEntry: TimelineEntry {
    var date = Date()
    var pages: [IntentPanel] = []
}

private extension WidgetCache {
    func panels(timeout timeoutDuration: Measurement<UnitDuration>) -> Promise<HAPanels> {
        let key = "panels"

        let cached: () -> Promise<HAPanels> = { [self] in
            Promise { seal in
                seal.fulfill(try value(for: key))
            }
        }

        let result: Promise<HAPanels> = firstly {
            Current.apiConnection.caches.panels.once().promise
        }.recover { error in
            // the message itself failed; not fired for connection issues
            cached()
        }.get { [self] value in
            try set(value, for: key)
        }

        let timeout = after(seconds: timeoutDuration.converted(to: .seconds).value)
        return race(result, timeout.then(cached))
    }
}

struct WidgetOpenPageProvider: IntentTimelineProvider {
    typealias Intent = WidgetOpenPageIntent
    typealias Entry = WidgetOpenPageEntry

    @SwiftUI.Environment(\.widgetCache)
    var widgetCache: WidgetCache

    func placeholder(in context: Context) -> WidgetOpenPageEntry {
        let count = WidgetBasicContainerView.maximumCount(family: context.family)
        let pages = stride(from: 0, to: count, by: 1).map { idx in
            with(IntentPanel(identifier: "redacted\(idx)", display: "Redacted Text")) {
                $0.icon = MaterialDesignIcons.bedEmptyIcon.name
            }
        }

        return .init(pages: pages)
    }

    private func panels(
        for context: Context,
        timeout: Measurement<UnitDuration> = .init(value: 15.0, unit: .seconds)
    ) -> Promise<[IntentPanel]> {
        firstly {
            widgetCache.panels(timeout: timeout)
        }.map { panels in
            panels.allPanels.prefix(WidgetBasicContainerView.maximumCount(family: context.family))
        }.mapValues {
            IntentPanel(panel: $0)
        }
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        if let pages = configuration.pages, !pages.isEmpty {
            completion(.init(pages: pages))
            return
        }

        panels(
            for: context,
            timeout: .init(value: 5.0, unit: .seconds)
        ).map { panels in
            Entry(pages: panels)
        }.recover { error in
            Current.Log.error("failed to provide snapshot: \(error)")
            return .value(Entry(pages: []))
        }.done { panels in
            completion(panels)
        }
    }

    private static var expiration: Measurement<UnitDuration> {
        .init(value: 60, unit: .minutes)
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        func timeline(for pages: [IntentPanel]) -> Timeline<Entry> {
            return .init(
                entries: [.init(pages: pages)],
                policy: .after(Current.date().addingTimeInterval(Self.expiration.converted(to: .seconds).value))
            )
        }

        let existing: [IntentPanel]? = configuration.pages.flatMap { $0.isEmpty ? nil : $0 }

        panels(for: context).recover { error -> Promise<[IntentPanel]> in
            // if the panels were configured, fall back to the saved value
            if let existing = existing {
                return .value(existing)
            } else {
                throw error
            }
        }.map { panels -> [IntentPanel] in
            if let existing = existing {
                // the configured values may be ancient, use the newer version but keep the same list
                return existing.compactMap { existingValue in
                    panels.first(where: { $0.identifier == existingValue.identifier }) ?? existingValue
                }
            } else {
                return panels
            }
        }.map { panels in
            timeline(for: panels)
        }.done {
            completion($0)
        }.catch { error in
            Current.Log.error("failed to create a timeline: \(error)")
        }
    }
}
