//
//  WatchCommunicatorService.swift
//  WatchExtension-Watch
//
//  Created by Bruno Pantaleão on 11/06/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Communicator
import Shared

struct ImmediateCommunicatorServiceObserver {
    weak var delegate: (any ImmediateCommunicatorServiceDelegate)?
}

protocol ImmediateCommunicatorServiceDelegate: AnyObject {
    func didReceiveChatItem(_ item: AssistChatItem)
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
            observers.forEach({ $0.delegate?.didReceiveChatItem(AssistChatItem(content: content, itemType: .input))})
        case .assistIntentEndResponse:
            guard let content = message.content["content"] as? String else {
                Current.Log.error("Received assistIntentEndResponse without content")
                return
            }
            observers.forEach({ $0.delegate?.didReceiveChatItem(AssistChatItem(content: content, itemType: .output))})
        case .assistTTSResponse:
            break
        default:
            break
        }
    }
}
