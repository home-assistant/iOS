import Communicator
import Foundation
import Shared

struct ImmediateCommunicatorServiceObserver {
    weak var delegate: (any ImmediateCommunicatorServiceDelegate)?
}

protocol ImmediateCommunicatorServiceDelegate: AnyObject {
    func didReceiveChatItem(_ item: AssistChatItem)
    func didReceiveTTS(url: URL)
}

final class ImmediateCommunicatorService {
    static var shared = ImmediateCommunicatorService()
    private var observers: [ImmediateCommunicatorServiceObserver] = []

    func addObserver(_ observer: ImmediateCommunicatorServiceObserver) {
        observers.append(observer)
    }

    func removeObserver(_ observerDelegate: ImmediateCommunicatorServiceDelegate) {
        observers.removeAll { $0.delegate === observerDelegate }
    }

    func evaluateMessage(_ message: ImmediateMessage) {
        guard let messageId = InteractiveImmediateResponses(rawValue: message.identifier) else {
            Current.Log.error("Received communicator message that cant be mapped to messages responses enum")
            return
        }

        switch messageId {
        case .assistSTTResponse:
            guard let content = message.content["content"] as? String else {
                Current.Log.error("Received assistSTTResponse without content")
                return
            }
            observers.forEach({ $0.delegate?.didReceiveChatItem(AssistChatItem(content: content, itemType: .input)) })
        case .assistIntentEndResponse:
            guard let content = message.content["content"] as? String else {
                Current.Log.error("Received assistIntentEndResponse without content")
                return
            }
            observers.forEach({ $0.delegate?.didReceiveChatItem(AssistChatItem(content: content, itemType: .output)) })
        case .assistTTSResponse:
            guard let audioURLString = message.content["mediaURL"] as? String,
                  let audioURL = URL(string: audioURLString) else {
                Current.Log.error("Received assistTTSResponse without valid media URL")
                return
            }
            observers.forEach({ $0.delegate?.didReceiveTTS(url: audioURL) })
        default:
            break
        }
    }
}
