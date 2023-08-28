//
//  WatchActionService.swift
//  App
//
//  Created by Bruno Pantaleão on 28/08/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import Communicator
import PromiseKit

public class WatchActionService: WatchCommunicationProtocol {
    public func handle(message: InteractiveImmediateMessage) {
        Current.Log.verbose("Received ActionRowPressed \(message) \(message.content)")
        let responseIdentifier = "ActionRowPressedResponse"

        guard let actionID = message.content["ActionID"] as? String,
              let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID),
              let server = Current.servers.server(for: action) else {
            Current.Log.warning("ActionID either does not exist or is not a string in the payload")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        firstly {
            Current.api(for: server).HandleAction(actionID: actionID, source: .Watch)
        }.done {
            message.reply(.init(identifier: responseIdentifier, content: ["fired": true]))
        }.catch { err in
            Current.Log.error("Error during action event fire: \(err)")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
        }
    }
}
