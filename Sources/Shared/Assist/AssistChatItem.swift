import Foundation

public struct AssistChatItem: Equatable {
    public init(id: String = UUID().uuidString, content: String, itemType: AssistChatItem.ItemType) {
        self.id = id
        self.content = content
        self.itemType = itemType
        self.markdown = (try? AttributedString(markdown: content)) ?? AttributedString(content)
    }

    public var id: String = UUID().uuidString
    public let content: String
    public let itemType: ItemType
    public let markdown: AttributedString

    public enum ItemType {
        case input
        case output
        case typing
        case error
        case info
    }
}
