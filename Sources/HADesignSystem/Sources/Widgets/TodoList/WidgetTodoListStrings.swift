#if !os(watchOS)
import Foundation

/// The copy the to-do widget draws, handed in by the app so it arrives translated.
public struct WidgetTodoListStrings {
    public let title: String
    public let selectList: String
    public let allDone: String

    public init(title: String, selectList: String, allDone: String) {
        self.title = title
        self.selectList = selectList
        self.allDone = allDone
    }

    /// English stand-ins, for previews and the component gallery.
    public static let preview = WidgetTodoListStrings(
        title: "To-do list",
        selectList: "Select a list to show",
        allDone: "All done!"
    )
}
#endif
