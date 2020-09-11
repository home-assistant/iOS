import WidgetKit
import Shared

struct WidgetActionsEntry: TimelineEntry {
    var date: Date = Date()
    var actions: [Action] = []
}

struct WidgetActionsProvider: IntentTimelineProvider {
    typealias Intent = WidgetActionsIntent
    typealias Entry = WidgetActionsEntry

    private static func actionCount(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 4
        case .systemLarge: return 8
        @unknown default: return 8
        }
    }

    func placeholder(in context: Context) -> WidgetActionsEntry {
        let actions = stride(from: 0, to: Self.actionCount(for: context.family), by: 1).map { _ in
            with(Action()) {
                $0.Text = "Redacted Text"
                $0.IconName = MaterialDesignIcons.bedEmptyIcon.name
            }
        }

        return .init(actions: actions)
    }

    private static func defaultActions(in context: Context) -> [Action] {
        let allActions = Current.realm().objects(Action.self).sorted(byKeyPath: #keyPath(Action.Position))
        let maxCount = Self.actionCount(for: context.family)

        switch allActions.count {
        case 0: return []
        case ...maxCount: return Array(allActions)
        default: return Array(allActions[0 ..< maxCount])
        }
    }

    private static func entry(for configuration: Intent, in context: Context) -> Entry {
        if let existing = configuration.actions?.compactMap({ $0.asAction() }), !existing.isEmpty {
            return .init(actions:  existing)
        } else {
            return .init(actions: Self.defaultActions(in: context))
        }
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Self.entry(for: configuration, in: context))
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [ Self.entry(for: configuration, in: context) ], policy: .never))
    }
}
