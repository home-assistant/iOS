import Foundation
import WatchKit

struct AssistConversationData {
    let content: String
    let type: ContentType

    enum ContentType {
        case input, output
    }
}

enum AssistMicStates {
    case loading
    case standard
    case inProgress
}
