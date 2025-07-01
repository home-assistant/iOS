import Foundation

public struct AssistChatItem: Equatable {
    public init(id: String = UUID().uuidString, content: String, itemType: AssistChatItem.ItemType) {
        self.id = id
        self.content = content
        self.itemType = itemType
    }

    public var id: String = UUID().uuidString
    public let content: String
    public var markdown: AttributedString {
        (try? AttributedString(markdown: self.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible))) ?? AttributedString(self.content)
    }
    public let itemType: ItemType

    public enum ItemType {
        case input
        case output
        case typing
        case error
        case info
    }
}
