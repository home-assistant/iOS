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

public class ClientEventTableViewController: UITableViewController, UISearchResultsUpdating {
    private var dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private var results: AnyRealmCollection<ClientEvent> = AnyRealmCollection(List<ClientEvent>()) {
        didSet {
            tableView.reloadData()
            notificationToken?.invalidate()
            notificationToken = results.observe { [tableView] changes in
                tableView?.applyChanges(changes: changes)
            }
        }
    }

    private var notificationToken: NotificationToken?

    override public func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = L10n.Settings.EventLog.title
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.ClientEvents.View.clear,
            style: .plain, target: self,
            action: #selector(clearTapped(_:))
        )
        navigationItem.searchController = with(UISearchController(searchResultsController: nil)) {
            $0.searchResultsUpdater = self
            $0.obscuresBackgroundDuringPresentation = false
        }

        results = Current.clientEventStore.getEvents()
    }

    deinit {
        notificationToken?.invalidate()
    }

    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.ClientEvents(segue) else {
            return
        }

        if segueType == .showPayload, let destination = segue.destination as? ClientEventPayloadViewController {
            guard let selectedIndexPath = self.tableView.indexPathForSelectedRow else {
                return
            }
            destination.showEvent(results[selectedIndexPath.row])
        }
    }

    @objc private func clearTapped(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(
            title: L10n.ClientEvents.View.ClearConfirm.title,
            message: L10n.ClientEvents.View.ClearConfirm.message,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.barButtonItem = sender

        alertController.addAction(UIAlertAction(title: L10n.ClientEvents.View.clear, style: .destructive) { _ in
            Current.clientEventStore.clearAllEvents()
        })
        alertController.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))

        present(alertController, animated: true, completion: nil)
    }

    public func updateSearchResults(for searchController: UISearchController) {
        results = Current.clientEventStore.getEvents(filter: searchController.searchBar.text)
    }
}

extension ClientEventTableViewController {
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if results[indexPath.row].jsonPayload == nil {
            return nil
        } else {
            return indexPath
        }
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell", for: indexPath) as UITableViewCell
        if results.count > indexPath.item, let eventCell = cell as? ClientEventCell {
            let item = results[indexPath.item]
            eventCell.titleLabel.text = item.text
            eventCell.dateLabel.text = self.dateFormatter.string(from: item.date)
            eventCell.typeLabel.text = item.type.displayText

            if item.jsonPayload != nil {
                eventCell.accessoryType = .disclosureIndicator
                eventCell.selectionStyle = .default
            } else {
                eventCell.accessoryType = .none
                eventCell.selectionStyle = .none
            }
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
            self.deleteRows(at: deletions.map(fromRow), with: .automatic)
            self.reloadRows(at: updates.map(fromRow), with: .automatic)
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
