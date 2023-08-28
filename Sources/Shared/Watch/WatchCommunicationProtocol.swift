//
//  WatchCommunicationProtocol.swift
//  App
//
//  Created by Bruno Pantaleão on 28/08/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import Communicator

public protocol WatchCommunicationProtocol {
    func handle(message: InteractiveImmediateMessage)
}

public enum WatchCommunicationKey: String {
    case actionRow = "ActionRowPressed"
    case pushAction = "PushAction"
    case assist = "AssistRequest"
}
