import Foundation

struct AssistChatItem: Equatable {
    var id: String = UUID().uuidString
    let content: String
    let itemType: ItemType

    enum ItemType {
        case input
        case output
        case error
        case info
    }
}
