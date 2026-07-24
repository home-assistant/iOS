import Foundation
import Shared

struct ImmediateCommunicatorServiceObserver {
    weak var delegate: (any ImmediateCommunicatorServiceDelegate)?
}

protocol ImmediateCommunicatorServiceDelegate: AnyObject {
    func didReceiveChatItem(_ item: AssistChatItem)
    func didReceiveTTS(url: URL)
    func didReceiveError(code: String, message: String)
}

final class ImmediateCommunicatorService {
    static var shared = ImmediateCommunicatorService()
    private var observers: [ImmediateCommunicatorServiceObserver] = []

    func addObserver(_ observer: ImmediateCommunicatorServiceObserver) {
        // Prune released delegates: a deallocated observer can't unregister itself (its weak
        // delegate is already nil during deinit, so `removeObserver` matches nothing).
        observers.removeAll { $0.delegate == nil }
        observers.append(observer)
    }

    func removeObserver(_ observerDelegate: ImmediateCommunicatorServiceDelegate) {
        observers.removeAll { $0.delegate === observerDelegate }
    }

    func evaluateMessage(_ message: HAWatchConnectivity.ImmediateMessage) {
        guard let messageId = InteractiveImmediateResponses(rawValue: message.identifier) else {
            Current.Log.error("Received communicator message that cant be mapped to messages responses enum")
            return
        }

        switch messageId {
        case .assistSTTResponse:
            guard let payload = AssistTextResponsePayload(content: message.content) else {
                Current.Log.error("Received assistSTTResponse without content")
                return
            }
            for observer in observers {
                observer.delegate?
                    .didReceiveChatItem(AssistChatItem(content: payload.text, itemType: .input))
            }
        case .assistIntentEndResponse:
            guard let payload = AssistTextResponsePayload(content: message.content) else {
                Current.Log.error("Received assistIntentEndResponse without content")
                return
            }
            for observer in observers {
                observer.delegate?
                    .didReceiveChatItem(AssistChatItem(content: payload.text, itemType: .output))
            }
        case .assistTTSResponse:
            guard let payload = AssistTTSResponsePayload(content: message.content) else {
                Current.Log.error("Received assistTTSResponse without valid media URL")
                return
            }
            observers.forEach({ $0.delegate?.didReceiveTTS(url: payload.mediaURL) })
        case .assistError:
            guard let payload = AssistErrorPayload(content: message.content) else {
                Current.Log.error("Received assistError without valid code/message")
                return
            }
            observers.forEach({ $0.delegate?.didReceiveError(code: payload.code, message: payload.message) })
        default:
            break
        }
    }
}
