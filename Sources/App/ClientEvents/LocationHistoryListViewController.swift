import Eureka
import RealmSwift
import Shared
import UIKit

class LocationHistoryListViewController: HAFormViewController {
    private var section: RealmSection<LocationHistoryEntry>?

    @objc private func clear(_ sender: AnyObject?) {
        let realm = Current.realm()
        realm.reentrantWrite {
            realm.delete(realm.objects(LocationHistoryEntry.self))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
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
            $0.dateStyle = .short
            $0.timeStyle = .medium
        }

        let section = RealmSection(
            header: nil,
            footer: nil,
            collection: AnyRealmCollection(history),
            emptyRows: [
                with(InfoLabelRow()) {
                    $0.displayType = .secondary
                    $0.title = L10n.Settings.LocationHistory.empty
                },
            ], getter: { [weak self] entry in
                with(ButtonRowWithPresent<LocationHistoryDetailViewController>()) {
                    $0.cellStyle = .subtitle
                    $0.title = formatter.string(from: entry.CreatedAt)
                    $0.cellUpdate { cell, _ in
                        if #available(iOS 13, *) {
                            cell.detailTextLabel?.textColor = .secondaryLabel
                        } else {
                            cell.detailTextLabel?.textColor = .gray
                        }

                        cell.detailTextLabel?.text = entry.Trigger
                        cell.accessoryType = .disclosureIndicator
                    }
                    $0.onCellSelection { _, row in
                        // undo the deselect the button row does so returning feels good
                        row.select()
                    }
                    $0.presentationMode = .show(controllerProvider: .callback(builder: {
                        with(LocationHistoryDetailViewController(entry: entry)) { controller in
                            controller.moveDelegate = self
                        }
                    }), onDismiss: nil)
                }
            }, didUpdate: { _, _ in
            }
        )
        self.section = section
        form +++ section
    }
}

extension LocationHistoryListViewController: LocationHistoryDetailMoveDelegate {
    private func row(
        from row: RowOf<LocationHistoryDetailViewController>,
        in direction: LocationHistoryDetailViewController.MoveDirection
    ) -> ButtonRowWithPresent<LocationHistoryDetailViewController>? {
        guard let indexPath = row.indexPath, let section = section else {
            return nil
        }

        let nextIndex: Int?

        switch direction {
        case .up where section.startIndex < indexPath.row: nextIndex = section.index(before: indexPath.row)
        case .down where section.endIndex - 1 > indexPath.row: nextIndex = section.index(after: indexPath.row)
        default: nextIndex = nil
        }

        if let nextIndex = nextIndex {
            return section[nextIndex] as? ButtonRowWithPresent<LocationHistoryDetailViewController>
        } else {
            return nil
        }
    }

    func detail(
        _ controller: LocationHistoryDetailViewController,
        canMove direction: LocationHistoryDetailViewController.MoveDirection
    ) -> Bool {
        row(from: controller.row, in: direction) != nil
    }

    func detail(
        _ controller: LocationHistoryDetailViewController,
        move direction: LocationHistoryDetailViewController.MoveDirection
    ) {
        guard let navigationController = navigationController,
              let nextRow = row(from: controller.row, in: direction),
              let nextController = nextRow.presentationMode?.makeController() else {
            return
        }

        controller.row.deselect(animated: false)
        nextController.row = nextRow

        var controllers = navigationController.viewControllers
        controllers.removeLast()
        controllers.append(nextController)
        navigationController.setViewControllers(controllers, animated: false)

        nextRow.select(animated: true, scrollPosition: .middle)
    }
}
