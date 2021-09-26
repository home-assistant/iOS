import Shared
import WidgetKit
import PromiseKit

struct WidgetOpenPageEntry: TimelineEntry {
    var date = Date()
    var pages: [IntentPanel] = []
}

struct WidgetOpenPageProvider: IntentTimelineProvider {
    typealias Intent = WidgetOpenPageIntent
    typealias Entry = WidgetOpenPageEntry

    func placeholder(in context: Context) -> WidgetOpenPageEntry {
        let count = WidgetBasicContainerView.maximumCount(family: context.family)
        let pages = stride(from: 0, to: count, by: 1).map { idx in
            with(IntentPanel(identifier: "redacted\(idx)", display: "Redacted Text")) {
                $0.icon = MaterialDesignIcons.bedEmptyIcon.name
            }
        }

        return .init(pages: pages)
    }

    private func dynamicPages(for context: Context) -> Promise<[IntentPanel]> {
        firstly {
            Current.apiConnection.send(.panels()).promise
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

        dynamicPages(for: context).map { panels in
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

        if let pages = configuration.pages, !pages.isEmpty {
            completion(timeline(for: pages))
        } else {
            dynamicPages(for: context).map { panels in
                return timeline(for: panels)
            }.done {
                completion($0)
            }.catch { error in
                Current.Log.error("failed to create a timeline: \(error)")
            }
        }
    }
}
