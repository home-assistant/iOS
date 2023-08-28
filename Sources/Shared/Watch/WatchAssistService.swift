import Communicator
import Foundation
import PromiseKit

public class WatchAssistService: WatchCommunicationProtocol {
    // TODO: Improve this strong reference somehow to keep the type 'AssistIntentHandler' even though its iOS13+ only
    private var assistIntentHandler: WatchAssistIntentWrapping?

    public init() {}

    public func handle(message: InteractiveImmediateMessage) {
        #if os(iOS)
        Current.Log.verbose("Received AssistRequest \(message) \(message.content)")
        guard #available(iOS 13, *) else {
            reply(message: message, answer: NSLocalizedString("iOS13+ is required", comment: ""))
            return
        }

        guard let audioData = message.content["Input"] as? Data else {
            reply(message: message, answer: NSLocalizedString("Couldn't read input text", comment: ""))
            return
        }

        assistIntentHandler = Current.watchAssistWrapper
        assistIntentHandler?.handle(audioData: audioData) { [weak self] inputText, response in
            guard let displayString = response.result?.displayString else {
                self?.reply(
                    message: message,
                    answer: NSLocalizedString("Couldn't read response from Assist", comment: "")
                )
                return
            }
            self?.reply(message: message, answer: displayString, inputText: inputText)
        }
        #endif
    }

    private func reply(message: InteractiveImmediateMessage, answer: String, inputText: String? = nil) {
        message.reply(.init(
            identifier: "AssistAnswer",
            content: [
                "answer": answer,
                "inputText": inputText,
            ]
        ))
    }
}
