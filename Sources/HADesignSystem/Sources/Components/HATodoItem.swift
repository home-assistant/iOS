import Foundation

/// One entry in an ``HATodoListCard``.
///
/// Distinct from `WidgetTodoItemModel`, which the To-do widget draws — that one carries only what
/// fits in a widget row, where this has the due date and description a card has room for.
///
/// Frontend counterpart: the `TodoItem` data `hui-todo-list-card` renders, rather than an element
/// of its own.
public struct HATodoItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let summary: String
    public let description: String?
    public let dueDate: Date?
    public let isCompleted: Bool

    public init(
        id: String,
        summary: String,
        description: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.summary = summary
        self.description = description
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
}

extension HATodoItem: FrontendComponent {
    public static var frontendComponentName: String { "hui-todo-list-card" }
}
