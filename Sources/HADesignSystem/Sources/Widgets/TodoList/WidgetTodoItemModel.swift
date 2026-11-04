#if !os(watchOS)
import Foundation

/// One to-do as the widget draws it: what it says, and when it is due in words the app has already
/// worked out and translated.
public struct WidgetTodoItemModel: Identifiable, Hashable {
    public let id: String
    public let summary: String
    /// Already-formatted due text ("Tomorrow", "In 20 minutes"), or `nil` for an item with no date.
    public let dueText: String?
    /// Whether that due date has passed, which is what turns the clock and its caption orange.
    public let isOverdue: Bool

    public init(id: String, summary: String, dueText: String? = nil, isOverdue: Bool = false) {
        self.id = id
        self.summary = summary
        self.dueText = dueText
        self.isOverdue = isOverdue
    }
}
#endif
