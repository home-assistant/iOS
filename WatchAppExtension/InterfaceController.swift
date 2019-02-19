//
//  InterfaceController.swift
//  WatchApp Extension
//
//  Created by Robert Trencheny on 9/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import WatchKit
import Iconic
import EMTLoadingIndicator
import RealmSwift
import Communicator

class InterfaceController: WKInterfaceController {
    @IBOutlet weak var tableView: WKInterfaceTable!

    var actions: Results<Action>?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        print("ONE")

        Iconic.registerMaterialDesignIcons()

        self.setupTable()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func setupTable() {
        let realm = Realm.live()

        let actions = realm.objects(Action.self).sorted(byKeyPath: "Position")

        self.tableView.setNumberOfRows(actions.count, withRowType: "actionRowType")

        for (i, action) in actions.enumerated() {
            if let row = self.tableView.rowController(at: i) as? ActionRowType {
                print("Setup row \(i) with action", action)
                row.group.setBackgroundColor(UIColor(hex: action.BackgroundColor))
                row.indicator = EMTLoadingIndicator(interfaceController: self, interfaceImage: row.image,
                                                    width: 24, height: 24, style: .dot)
                row.icon = MaterialDesignIcons.init(named: action.IconName)
                let iconColor = UIColor(hex: action.IconColor)
                row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24), color: iconColor))
                row.image.setAlpha(1)
                row.label.setText(action.Text)
                row.label.setTextColor(UIColor(hex: action.TextColor))
            }
        }

        self.actions = actions

    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let selectedAction = self.actions![rowIndex]

        print("Selected action row at index", rowIndex, selectedAction)

        guard let row = self.tableView.rowController(at: rowIndex) as? ActionRowType else {
            print("Row at", rowIndex, "is not ActionRowType")
            return
        }

        row.indicator?.prepareImagesForWait()
        row.indicator?.showWait()

        let actionMessage = ImmediateMessage(identifier: "ActionRowPressed",
                                             content: ["ActionID": selectedAction.ID,
                                                       "ActionName": selectedAction.Name], replyHandler: { replyDict in
                                                print("Received reply dictionary", replyDict)

                                                WKInterfaceDevice.current().play(.success)

                                                row.image.stopAnimating()

                                                row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24),
                                                                                  color: .white))
        }, errorHandler: { err in
            print("Received error when sending immediate message", err)

            WKInterfaceDevice.current().play(.failure)

            row.image.stopAnimating()

            row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24),
                                              color: .white))
        })

        print("Sending ActionRowPressed message", actionMessage)

        do {
            try Communicator.shared.send(immediateMessage: actionMessage)
            WKInterfaceDevice.current().play(.success)
        } catch let error {
            print("Action notification send failed:", error)

            WKInterfaceDevice.current().play(.failure)

            row.image.stopAnimating()

            row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24),
                                              color: .white))
        }
    }
}
