//
//  ClientEventTableViewController.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/18/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import RealmSwift
import Shared
import UIKit

public class ClientEventTableViewController: UITableViewController {
    var dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var results: Results<ClientEvent>?
    var notificationToken: NotificationToken?
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = L10n.Settings.EventLog.title
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.ClientEvents.View.clear,
                                                                 style: .plain, target: self,
                                                                 action: #selector(clearTapped))
        self.results = Current.clientEventStore.getEvents()
        self.notificationToken = self.results?.observe { changes in
            self.tableView.applyChanges(changes: changes)
        }
    }
    deinit {
        notificationToken = nil
    }

    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "showPayload",
            let selectedIndexPath = self.tableView.indexPathForSelectedRow,
            let event = results?[selectedIndexPath.row],
            let payloadVC = segue.destination as? ClientEventPayloadViewController {
            payloadVC.showEvent(event)
        }
    }
    @objc func clearTapped() {
        Current.clientEventStore.clearAllEvents()
    }
}

extension ClientEventTableViewController {
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.results?.count ?? 0
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell",
                                                 for: indexPath) as UITableViewCell
        if let item = self.results?[indexPath.item], let eventCell = cell as? ClientEventCell {
            eventCell.titleLabel.text = item.text
            eventCell.dateLabel.text = self.dateFormatter.string(from: item.date)
            eventCell.typeLabel.text = item.type.displayText
        }
        return cell
    }
}

extension UITableView {
    func applyChanges<T>(changes: RealmCollectionChange<T>) {
        switch changes {
        case .initial: self.reloadData()
        case .update(_, let deletions, let insertions, let updates):
            let fromRow = { (row: Int) in return IndexPath(row: row, section: 0) }

            self.beginUpdates()
            self.insertRows(at: insertions.map(fromRow), with: .automatic)
            self.reloadRows(at: updates.map(fromRow), with: .automatic)
            self.deleteRows(at: deletions.map(fromRow), with: .automatic)
            self.endUpdates()
        case .error(let error): fatalError("\(error)")
        }
    }
}

extension ClientEvent.EventType {
    var displayText: String {
        switch self {
        case .notification:
            return L10n.ClientEvents.EventType.notification
        case .locationUpdate:
            return L10n.ClientEvents.EventType.locationUpdate
        case .serviceCall:
            return L10n.ClientEvents.EventType.serviceCall
        case .networkRequest:
            return L10n.ClientEvents.EventType.networkRequest
        case .unknown:
            return L10n.ClientEvents.EventType.unknown
        }
    }
}
