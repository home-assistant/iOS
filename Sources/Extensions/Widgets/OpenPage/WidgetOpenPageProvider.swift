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
        updating existing: [IntentPanel],
        timeout: Measurement<UnitDuration> = .init(value: 10.0, unit: .seconds)
    ) -> Promise<[IntentPanel]> {
        firstly { () -> Promise<[IntentPanel]> in
            when(fulfilled: Current.apis.map { api -> Promise<[IntentPanel]> in
                let diskCacheKey = "panels-\(api.server.identifier)"
                let apiCache = api.connection.caches.panels
                apiCache.shouldResetWithoutSubscribers = true

                let result = apiCache.once().promise.get { value in
                    diskCache.set(value, for: diskCacheKey).cauterize()
                }

                let timeout: Promise<HAPanels> = firstly {
                    after(seconds: timeout.converted(to: .seconds).value)
                }.then {
                    // grab from cache after timeout
                    diskCache.value(for: diskCacheKey)
                }

                return race(Promise(result), timeout)
                    .map(\.allPanels)
                    .mapValues { IntentPanel(panel: $0, server: api.server) }
            }).map {
                // [[IntentPanel]] -> [IntentPanel]
                $0.flatMap { $0 }
            }.map { intentified -> [IntentPanel] in
                if existing.isEmpty {
                    return intentified
                } else {
                    // the configured values may be ancient, use the newer version but keep the same list
                    return existing.compactMap { existingValue in
                        intentified.first(where: {
                            $0.identifier == existingValue.identifier &&
                                $0.server == existingValue.server
                        }) ?? existingValue
                    }
                }
            }
        }.recover { error throws -> Promise<[IntentPanel]> in
            if existing.isEmpty {
                throw error
            }
            return .value(existing)
        }.map { panels in
            Array(panels.prefix(WidgetBasicContainerView.maximumCount(family: context.family)))
        }
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        panels(
            for: context,
            updating: configuration.pages ?? [],
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

        panels(
            for: context,
            updating: configuration.pages ?? []
        ).map { panels in
            timeline(for: panels)
        }.done {
            completion($0)
        }.catch { error in
            Current.Log.error("failed to create a timeline: \(error)")
            completion(timeline(for: []))
        }
    }
}
