//
//  AssistInterfaceController.swift
//  WatchApp
//
//  Created by Bruno Pantaleão on 18/08/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Communicator
import Foundation
import PromiseKit
import Shared
import WatchKit

class AssistInterfaceController: WKInterfaceController {

    @IBOutlet weak var inputCommand: WKInterfaceLabel!
    @IBOutlet weak var assistResponse: WKInterfaceLabel!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        requestInput()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func didTapAssist() {
        requestInput()
    }

    private func requestInput() {
        self.presentTextInputController(withSuggestions: nil, allowedInputMode: .plain) { [weak self] response in
            guard let firstResponse = response?.first as? String else { return }
            self?.inputCommand.setText(firstResponse)
            self?.assistResponse.setText("Loading...")
            self?.assist(inputText: firstResponse)
        }
    }

    private func assist(inputText: String) {
        enum SendError: Error {
            case notImmediate
            case phoneFailed
        }

        firstly { () -> Promise<Void> in
            Promise { seal in
                guard Communicator.shared.currentReachability == .immediatelyReachable else {
                    seal.reject(SendError.notImmediate)
                    return
                }

                Current.Log.verbose("Signaling assist pressed via phone")
                let actionMessage = InteractiveImmediateMessage(
                    identifier: "AssistRequest",
                    content: ["Input": inputText],
                    reply: { [weak self] message in
                        Current.Log.verbose("Received reply dictionary \(message)")
                        guard let answer = message.content["answer"] as? String else { return }
                        self?.assistResponse.setText(answer)
                        seal.fulfill(())
                    }
                )

                Current.Log.verbose("Sending AssistRequest message \(actionMessage)")
                Communicator.shared.send(actionMessage, errorHandler: { error in
                    Current.Log.error("Received error when sending immediate message \(error)")
                    seal.reject(error)
                })
            }
        }.recover { error -> Promise<Void> in
            Current.Log.error("recovering error \(error) by trying locally")
            return .value(())
        }.done {
            //
        }.catch { err in
            Current.Log.error("Error during action event fire: \(err)")
        }
    }
}
