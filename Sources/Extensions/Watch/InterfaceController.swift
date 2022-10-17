import Communicator
import EMTLoadingIndicator
import Foundation
import PromiseKit
import RealmSwift
import Shared
import WatchKit

class InterfaceController: WKInterfaceController {
    @IBOutlet var tableView: WKInterfaceTable!
    @IBOutlet var noActionsLabel: WKInterfaceLabel!

    var notificationToken: NotificationToken?

    var actions: Results<Action>?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        MaterialDesignIcons.register()

        setupTable()
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

        noActionsLabel.setText(L10n.Watch.Labels.noAction)

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
            case let .update(_, deletions, insertions, modifications):
                let insertionsSet = NSMutableIndexSet()
                insertions.forEach(insertionsSet.add)

                tableView.insertRows(at: IndexSet(insertionsSet), withRowType: "actionRowType")

                insertions.forEach(self.setupRow)

                let deletionsSet = NSMutableIndexSet()
                deletions.forEach(deletionsSet.add)

                tableView.removeRows(at: IndexSet(deletionsSet))

                modifications.forEach(self.setupRow)
            case let .error(error):
                // An error occurred while opening the Realm file on the background worker thread
                Current.Log.error("Error during Realm notifications! \(error)")
            }
        }
    }

    func setupRow(_ index: Int) {
        DispatchQueue.main.async {
            guard let row = self.tableView.rowController(at: index) as? ActionRowType,
                  let action = self.actions?[index] else { return }
            row.group.setBackgroundColor(UIColor(hex: action.BackgroundColor))
            row.indicator = EMTLoadingIndicator(
                interfaceController: self,
                interfaceImage: row.image,
                width: 24,
                height: 24,
                style: .dot
            )
            row.icon = MaterialDesignIcons(named: action.IconName)
            let iconColor = UIColor(hex: action.IconColor)
            row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24), color: iconColor))
            row.image.setAlpha(1)
            row.label.setText(action.Text)
            row.label.setTextColor(UIColor(hex: action.TextColor))
        }
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let selectedAction = actions![rowIndex]

        Current.Log.verbose("Selected action row at index \(rowIndex), \(selectedAction)")

        guard let row = tableView.rowController(at: rowIndex) as? ActionRowType else {
            Current.Log.warning("Row at \(rowIndex) is not ActionRowType")
            return
        }

        row.indicator?.prepareImagesForWait()
        row.indicator?.showWait()

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

                Current.Log.verbose("Signaling action pressed via phone")
                let actionMessage = InteractiveImmediateMessage(
                    identifier: "ActionRowPressed",
                    content: ["ActionID": selectedAction.ID],
                    reply: { message in
                        Current.Log.verbose("Received reply dictionary \(message)")
                        if message.content["fired"] as? Bool == true {
                            seal.fulfill(())
                        } else {
                            seal.reject(SendError.phoneFailed)
                        }
                    }
                )

                Current.Log.verbose("Sending ActionRowPressed message \(actionMessage)")
                Communicator.shared.send(actionMessage, errorHandler: { error in
                    Current.Log.error("Received error when sending immediate message \(error)")
                    seal.reject(error)
                })
            }
        }.recover { error -> Promise<Void> in
            guard error == SendError.notImmediate, let server = Current.servers.server(for: selectedAction) else {
                throw error
            }

            Current.Log.error("recovering error \(error) by trying locally")
            return Current.api(for: server).HandleAction(actionID: selectedAction.ID, source: .Watch)
        }.done {
            self.handleActionSuccess(row, rowIndex)
        }.catch { err in
            Current.Log.error("Error during action event fire: \(err)")
            self.handleActionFailure(row, rowIndex)
        }
    }

    func handleActionSuccess(_ row: ActionRowType, _ index: Int) {
        WKInterfaceDevice.current().play(.success)

        row.image.stopAnimating()

        setupRow(index)
    }

    func handleActionFailure(_ row: ActionRowType, _ index: Int) {
        WKInterfaceDevice.current().play(.failure)

        row.image.stopAnimating()

        setupRow(index)
    }

    deinit {
        notificationToken?.invalidate()
    }
}
