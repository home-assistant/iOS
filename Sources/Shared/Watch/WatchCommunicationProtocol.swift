import Communicator
import Foundation

public protocol WatchCommunicationProtocol {
    func handle(message: InteractiveImmediateMessage)
}

public enum WatchCommunicationKey: String {
    case actionRow = "ActionRowPressed"
    case pushAction = "PushAction"
    case assist = "AssistRequest"
}
