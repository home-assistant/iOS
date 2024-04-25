import Shared
import WidgetKit

struct WidgetActionsEntry: TimelineEntry {
    var date = Date()
    var actions: [Action] = []
}

struct WidgetActionsProvider: IntentTimelineProvider {
    typealias Intent = WidgetActionsIntent
    typealias Entry = WidgetActionsEntry

    func placeholder(in context: Context) -> WidgetActionsEntry {
        let count = WidgetBasicContainerView.maximumCount(family: context.family)
        let actions = stride(from: 0, to: count, by: 1).map { _ in
            with(Action()) {
                $0.Text = "Redacted Text"
                $0.IconName = MaterialDesignIcons.bedEmptyIcon.name
            }
        }

        return .init(actions: actions)
    }

    private static func defaultActions(in context: Context) -> [Action] {
        let allActions = Current.realm().objects(Action.self).sorted(byKeyPath: #keyPath(Action.Position))
        let maxCount = WidgetBasicContainerView.maximumCount(family: context.family)

        switch allActions.count {
        case 0: return []
        case ...maxCount: return Array(allActions)
        default: return Array(allActions[0 ..< maxCount])
        }
    }

    private static func entry(for configuration: Intent, in context: Context) -> Entry {
        if let existing = configuration.actions?.compactMap({ $0.asAction() }), !existing.isEmpty {
            return .init(actions: existing)
        } else {
            return .init(actions: Self.defaultActions(in: context))
        }
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Self.entry(for: configuration, in: context))
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [Self.entry(for: configuration, in: context)], policy: .never))
    }
}
