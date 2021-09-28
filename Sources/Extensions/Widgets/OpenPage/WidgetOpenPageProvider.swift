import PromiseKit
import Shared
import SwiftUI
import WidgetKit

struct WidgetOpenPageEntry: TimelineEntry {
    var date = Date()
    var pages: [IntentPanel] = []
}

private extension DiskCache {
    func panels(timeout timeoutDuration: Measurement<UnitDuration>, key: String = "panels") -> Promise<HAPanels> {
        let result: Promise<HAPanels> = firstly { () -> Guarantee<HAPanels> in
            let apiCache = Current.apiConnection.caches.panels
            apiCache.shouldResetWithoutSubscribers = true
            return apiCache.once().promise
        }.get { [self] value in
            set(value, for: key).cauterize()
        }

        let timeout: Promise<HAPanels> = firstly {
            after(seconds: timeoutDuration.converted(to: .seconds).value)
        }.then { [self] in
            // grab from cache after timeout
            value(for: key)
        }

        return race(result, timeout)
    }
}

struct WidgetOpenPageProvider: IntentTimelineProvider {
    typealias Intent = WidgetOpenPageIntent
    typealias Entry = WidgetOpenPageEntry

    @Environment(\.diskCache) var diskCache: DiskCache

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
            diskCache.panels(timeout: timeout)
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
        .init(value: 24, unit: .hours)
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        func timeline(for pages: [IntentPanel]) -> Timeline<Entry> {
            .init(
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
            completion(timeline(for: []))
        }
    }
}
