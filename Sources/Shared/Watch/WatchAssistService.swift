//
//  WatchAssistService.swift
//  App
//
//  Created by Bruno Pantaleão on 28/08/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import Communicator
import PromiseKit

public class WatchAssistService: WatchCommunicationProtocol {
    
    // TODO: Improve this strong reference somehow to keep the type 'AssistIntentHandler' even though its iOS13+ only
    private var assistIntentHandler: Any?

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

        assistIntentHandler = AssistIntentHandler()
        guard let assistIntentHandler = assistIntentHandler as? AssistIntentHandler else {
            reply(message: message, answer: NSLocalizedString("Couldn't read input text", comment: ""))
            return
        }
        assistIntentHandler.handle(audioData: audioData) { [weak self] inputText, response in
            guard let displayString = response.result?.displayString else {
                self?.reply(message: message, answer: NSLocalizedString("Couldn't read response from Assist", comment: ""))
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
                "inputText": inputText
            ]
        ))
    }
}
