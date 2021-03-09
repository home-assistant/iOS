import Eureka
import RealmSwift
import Shared
import UIKit

class LocationHistoryListViewController: FormViewController {
    @objc private func clear(_ sender: AnyObject?) {
        let realm = Current.realm()
        try? realm.write {
            realm.delete(realm.objects(LocationHistoryEntry.self))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.Settings.LocationHistory.title

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                title: L10n.ClientEvents.View.clear,
                style: .plain,
                target: self,
                action: #selector(clear(_:))
            ),
        ]

        let history = Current.realm()
            .objects(LocationHistoryEntry.self)
            .sorted(byKeyPath: "CreatedAt", ascending: false)

        let formatter = with(DateFormatter()) {
            $0.dateStyle = .medium
            $0.timeStyle = .medium
        }

        form +++ RealmSection(
            header: nil,
            footer: nil,
            collection: AnyRealmCollection(history),
            emptyRows: [
                with(InfoLabelRow()) {
                    $0.displayType = .secondary
                    $0.title = L10n.Settings.LocationHistory.empty
                },
            ], getter: { entry in
                with(ButtonRow()) {
                    $0.cellStyle = .subtitle
                    $0.title = formatter.string(from: entry.CreatedAt)
                    $0.cellUpdate { cell, _ in
                        cell.detailTextLabel?.text = "\(entry.Latitude), \(entry.Longitude)"
                        cell.accessoryType = .disclosureIndicator
                        if #available(iOS 13, *) {
                            cell.detailTextLabel?.textColor = .secondaryLabel
                        } else {
                            cell.detailTextLabel?.textColor = .gray
                        }
                    }
                    $0.presentationMode = .show(controllerProvider: .callback(builder: {
                        LocationHistoryDetailViewController(entry: entry)
                    }), onDismiss: nil)
                }
            }, didUpdate: { _, _ in
            }
        )
    }
}
