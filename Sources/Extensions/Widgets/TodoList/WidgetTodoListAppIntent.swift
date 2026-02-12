import AppIntents
import GRDB
import Shared
import WidgetKit

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetTodoListAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widgets.todo_list.title"

    static var isDiscoverable: Bool = false

    @Parameter(
        title: "widgets.todo_list.parameter.server"
    )
    var server: IntentServerAppEntity?

    @Parameter(
        title: "widgets.todo_list.parameter.list"
    )
    var list: TodoListAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$server
            \.$list
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: true)
    }
}
