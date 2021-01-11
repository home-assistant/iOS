//
//  InterfaceController.swift
//  WatchApp Extension
//
//  Created by Robert Trencheny on 9/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import WatchKit
import EMTLoadingIndicator
import RealmSwift
import Communicator
import Shared

class InterfaceController: WKInterfaceController {
    @IBOutlet weak var tableView: WKInterfaceTable!
    @IBOutlet weak var noActionsLabel: WKInterfaceLabel!

    var notificationToken: NotificationToken?

    var actions: Results<Action>?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        MaterialDesignIcons.register()

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

        self.noActionsLabel.setText(L10n.Watch.Labels.noAction)

        let actions = realm.objects(Action.self).sorted(byKeyPath: "Position")
        self.actions = actions

        notificationToken = actions.observe { (changes: RealmCollectionChange) in
            guard let tableView = self.tableView else { return }

            self.noActionsLabel.setHidden(actions.count > 0)

            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                self.tableView.setNumberOfRows(actions.count, withRowType: "actionRowType")

                for idx in actions.indices {
                    self.setupRow(idx)
                }
            case .update(_, let deletions, let insertions, let modifications):
                let insertionsSet = NSMutableIndexSet()
                insertions.forEach(insertionsSet.add)

                tableView.insertRows(at: IndexSet(insertionsSet), withRowType: "actionRowType")

                insertions.forEach(self.setupRow)

                let deletionsSet = NSMutableIndexSet()
                deletions.forEach(deletionsSet.add)

                tableView.removeRows(at: IndexSet(deletionsSet))

                modifications.forEach(self.setupRow)
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                Current.Log.error("Error during Realm notifications! \(error)")
            }
        }
    }

    func setupRow(_ index: Int) {
        DispatchQueue.main.async {
            guard let row = self.tableView.rowController(at: index) as? ActionRowType,
                let action = self.actions?[index] else { return }
            Current.Log.verbose("Setup row \(index) with action \(action)")
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

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let selectedAction = self.actions![rowIndex]

        Current.Log.verbose("Selected action row at index \(rowIndex), \(selectedAction)")

        guard let row = self.tableView.rowController(at: rowIndex) as? ActionRowType else {
            Current.Log.warning("Row at \(rowIndex) is not ActionRowType")
            return
        }

        row.indicator?.prepareImagesForWait()
        row.indicator?.showWait()

        if Communicator.shared.currentReachability == .immediatelyReachable {
            Current.Log.verbose("Signaling action pressed via phone")
            let actionMessage = InteractiveImmediateMessage(
                identifier: "ActionRowPressed",
                content: ["ActionID": selectedAction.ID],
                reply: { message in
                    Current.Log.verbose("Received reply dictionary \(message)")
                    self.handleActionSuccess(row, rowIndex)
                }
            )

            Current.Log.verbose("Sending ActionRowPressed message \(actionMessage)")

            Communicator.shared.send(actionMessage, errorHandler: { error in
                Current.Log.error("Received error when sending immediate message \(error)")
                self.handleActionFailure(row, rowIndex)
            })
        } else { // Phone isn't connected
            Current.Log.verbose("Signaling action pressed via watch")
            HomeAssistantAPI.authenticatedAPIPromise.then { api in
                api.HandleAction(actionID: selectedAction.ID, source: .Watch)
            }.done { _ in
                self.handleActionSuccess(row, rowIndex)
            }.catch { err -> Void in
                Current.Log.error("Error during action event fire: \(err)")
                self.handleActionFailure(row, rowIndex)
            }
        }
    }

    func handleActionSuccess(_ row: ActionRowType, _ index: Int) {
        WKInterfaceDevice.current().play(.success)

        row.image.stopAnimating()

        self.setupRow(index)
    }

    func handleActionFailure(_ row: ActionRowType, _ index: Int) {
        WKInterfaceDevice.current().play(.failure)

        row.image.stopAnimating()

        self.setupRow(index)
    }

    deinit {
        notificationToken?.invalidate()
    }
}
