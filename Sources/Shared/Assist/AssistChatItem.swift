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
        var content = (try? AttributedString(markdown: self.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible))) ?? AttributedString(self.content)
        for run in content.runs where run.attributes.link != nil {
            content[run.range].underlineStyle = .single
        }
        return content
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
