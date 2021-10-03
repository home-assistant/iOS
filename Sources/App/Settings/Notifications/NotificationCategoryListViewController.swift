import Eureka
import RealmSwift
import Shared

class NotificationCategoryListViewController: HAFormViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsDetails.Notifications.Categories.header

        navigationItem.rightBarButtonItems = [
            with(Constants.helpBarButtonItem) {
                $0.action = #selector(help)
                $0.target = self
            },
        ]

        let localCategories = Current.realm().objects(NotificationCategory.self)
            .filter("isServerControlled == NO")
            .sorted(byKeyPath: "Identifier")
        let serverCategories = Current.realm().objects(NotificationCategory.self)
            .filter("isServerControlled == YES")
            .sorted(byKeyPath: "Identifier")

        let mvOpts: MultivaluedOptions = [.Insert, .Delete]

        form +++ MultivaluedSection(
            multivaluedOptions: mvOpts,
            header: L10n.SettingsDetails.Notifications.Categories.header,
            footer: nil
        ) { section in
            section.tag = "notification_categories"
            section.multivaluedRowToInsertAt = { _ in
                self.getNotificationCategoryRow(nil)
            }
            section.addButtonProvider = { _ in
                ButtonRow {
                    $0.title = L10n.addButtonLabel
                    $0.cellStyle = .value1
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                }
            }

            for category in localCategories {
                section <<< getNotificationCategoryRow(category)
            }
        }

        form +++ RealmSection(
            header: L10n.SettingsDetails.Notifications.CategoriesSynced.header,
            footer: nil,
            collection: AnyRealmCollection(serverCategories),
            emptyRows: [
                LabelRow {
                    $0.title = L10n.SettingsDetails.Notifications.CategoriesSynced.empty
                    $0.disabled = true
                },
            ], getter: { [weak self] in self?.getNotificationCategoryRow($0) },
            didUpdate: { section, collection in
                if collection.isEmpty {
                    section.footer = HeaderFooterView(
                        title: L10n.SettingsDetails.Notifications.CategoriesSynced.footerNoCategories
                    )
                } else {
                    section.footer = HeaderFooterView(
                        title: L10n.SettingsDetails.Notifications.CategoriesSynced.footer
                    )
                }
            }
        )
    }

    func getNotificationCategoryRow(_ existingCategory: NotificationCategory?) ->
        ButtonRowWithPresent<NotificationCategoryConfigurator> {
        var category = existingCategory

        var identifier = "new_category_" + UUID().uuidString
        var title = L10n.SettingsDetails.Notifications.NewCategory.title

        if let category = category {
            identifier = category.Identifier
            title = category.Name
        }

        return ButtonRowWithPresent<NotificationCategoryConfigurator> { row in
            row.tag = identifier
            row.title = title
            row.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                NotificationCategoryConfigurator(category: category)
            }, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? NotificationCategoryConfigurator {
                    if vc.shouldSave == false {
                        Current.Log.verbose("Not saving category to DB and returning early!")
                        return
                    }

                    // if the user goes to re-edit the category after saving it, we want to show the same one
                    category = vc.category
                    row.tag = vc.category.Identifier
                    vc.row.title = vc.category.Name
                    vc.row.updateCell()

                    Current.Log.verbose("Saving category! \(vc.category)")

                    let realm = Current.realm()
                    realm.reentrantWrite {
                        realm.add(vc.category, update: .all)
                    }
                }
            })
        }
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)

        let deletedIDs = rows.compactMap(\.tag)

        if deletedIDs.count == 0 { return }

        Current.Log.verbose("Rows removed \(rows), \(deletedIDs)")

        let realm = Current.realm()

        if (rows.first as? ButtonRowWithPresent<NotificationCategoryConfigurator>) != nil {
            realm.reentrantWrite {
                realm.delete(realm.objects(NotificationCategory.self).filter("Identifier IN %@", deletedIDs))
            }
        }
    }

    @objc private func help() {
        openURLInBrowser(
            URL(string: "https://companion.home-assistant.io/app/ios/actionable-notifications")!,
            self
        )
    }
}
