import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 17.0, *)
struct TodoListRefreshAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh To-do List"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.todoList.rawValue)
        return .result()
    }
}
