import Foundation
import Eureka
import Shared
import RealmSwift
import Communicator
import Version

class ComplicationListViewController: FormViewController {
    init() {
        if #available(iOS 13, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func add(_ sender: UIBarButtonItem) {
        let editListViewController = ComplicationFamilySelectViewController(
            allowMultiple: supportsMultipleComplications,
            currentFamilies: Set(Current.realm().objects(WatchComplication.self).map(\.Family))
        )
        editListViewController.onDismissCallback = { $0.dismiss(animated: true, completion: nil) }
        let navigationController = UINavigationController(rootViewController: editListViewController)
        present(navigationController, animated: true, completion: nil)
    }

    private var supportsMultipleComplications: Bool {
        guard let string = Communicator.shared.mostRecentlyReceievedContext.content["watchVersion"] as? String else {
            return false
        }
        do {
            let version = try Version(string)
            return version >= Version(major: 7)
        } catch {
            Current.Log.error("failed to parse \(string), saying we're not 7+")
            return false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsDetails.Watch.title

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: L10n.addButtonLabel, style: .plain, target: self, action: #selector(add(_:)))
        ]

        form +++ InfoLabelRow {
            $0.title = L10n.Watch.Configurator.List.description
            $0.displayType = .primary
        }
        <<< ButtonRow {
            $0.title = L10n.Watch.Configurator.List.learnMore
            $0.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .natural
            }
            $0.onCellSelection { [weak self] _, _ in
                openURLInBrowser(URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!, self)
            }
        }

        let allComplications = Current.realm()
            .objects(WatchComplication.self)

        for group in ComplicationGroup.allCases.sorted() {
            let familyItems = allComplications
                .filter("rawFamily in %@", group.members.map(\.rawValue))
                .sorted(byKeyPath: "rawFamily")

            form +++ RealmSection(
                header: group.name,
                footer: group.description,
                collection: AnyRealmCollection(familyItems),
                emptyRows: [],
                getter: { (complication: WatchComplication) -> ButtonRow in
                    ButtonRow {
                        $0.cellStyle = .value1
                        $0.title = complication.Family.shortName
                        $0.value = complication.displayName
                        $0.cellUpdate { cell, row in
                            cell.detailTextLabel?.text = row.value
                        }
                        $0.presentationMode = .show(controllerProvider: .callback {
                            return ComplicationEditViewController(config: complication)
                        }, onDismiss: { vc in
                            _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }
                }, didUpdate: { section, collection in
                    let shouldBeHidden = collection.isEmpty
                    if shouldBeHidden != section.isHidden {
                        section.hidden = .init(booleanLiteral: shouldBeHidden)
                        section.evaluateHidden()
                    }
                }
            )
        }
    }
}
