import Eureka
import Foundation
import RealmSwift
import Shared
import UIKit
import UserNotifications

class NotificationCategoryConfigurator: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var category = NotificationCategory()
    var newCategory: Bool = true
    var shouldSave: Bool = false

    private var maxActionsForCategory = 10
    private var defaultMultivalueOptions: MultivaluedOptions = [.Reorder, .Insert, .Delete]
    private var addButtonRow = ButtonRow()
    private let realm = Current.realm()

    convenience init(category: NotificationCategory?) {
        self.init()

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }

        if let category = category {
            self.category = category
            if self.category.isServerControlled {
                self.defaultMultivalueOptions = []
            } else if self.category.Actions.count >= maxActionsForCategory {
                self.defaultMultivalueOptions = [.Reorder, .Delete]
            }
            self.newCategory = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        if !category.isServerControlled {
            let cancelSelector = #selector(NotificationCategoryConfigurator.cancel)

            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: cancelSelector
            )

            let saveSelector = #selector(NotificationCategoryConfigurator.save)

            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .save,
                target: self,
                action: saveSelector
            )
        }

        let infoBarButtonItem = Constants.helpBarButtonItem

        infoBarButtonItem.action = #selector(getInfoAction)
        infoBarButtonItem.target = self

        let previewButton = UIBarButtonItem(
            icon: .eyeIcon,
            target: self,
            action: #selector(NotificationCategoryConfigurator.preview)
        )

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)

        setToolbarItems([infoBarButtonItem, flexibleSpace, previewButton], animated: false)

        navigationController?.setToolbarHidden(false, animated: false)

        title = L10n.NotificationsConfigurator.Category.NavigationBar.title

        if newCategory == false {
            title = category.Name
        }

        TextRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        TextAreaRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.placeholderLabel?.textColor = .red
            }
        }

        NotificationIdentifierRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        let settingsFooter: String?

        if category.isServerControlled {
            settingsFooter = nil
        } else if newCategory {
            settingsFooter = L10n.NotificationsConfigurator.Settings.footer
        } else {
            settingsFooter = L10n.NotificationsConfigurator.Settings.Footer.idSet
        }

        form
            +++ Section(header: L10n.NotificationsConfigurator.Settings.header, footer: settingsFooter)

            <<< TextRow {
                $0.tag = "name"
                $0.title = L10n.NotificationsConfigurator.Category.Rows.Name.title
                $0.add(rule: RuleRequired())
                if self.category.isServerControlled {
                    $0.disabled = true
                }
                if !newCategory {
                    $0.value = self.category.Name
                }
            }.onChange { [realm] row in
                realm.reentrantWrite {
                    if let value = row.value {
                        self.category.Name = value
                    }
                }
            }

            <<< NotificationIdentifierRow {
                $0.tag = "identifier"
                $0.title = L10n.NotificationsConfigurator.identifier
                $0.uppercaseOnly = false
                if !newCategory {
                    $0.value = self.category.Identifier
                    $0.disabled = true
                }
            }.onChange { [realm] row in
                realm.reentrantWrite {
                    if let value = row.value {
                        self.category.Identifier = value
                    }
                }
            }

            +++ Section(
                header: L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.header,
                footer: L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.footer
            ) {
                if category.isServerControlled {
                    $0.hidden = true
                }
            }

            <<< TextAreaRow {
                $0.tag = "hiddenPreviewsBodyPlaceholder"
                $0.placeholder = L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.default
                if !newCategory, self.category.HiddenPreviewsBodyPlaceholder != "" {
                    $0.value = self.category.HiddenPreviewsBodyPlaceholder
                } else {
                    $0.value = L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.default
                }
            }.onChange { [realm] row in
                realm.reentrantWrite {
                    if let value = row.value {
                        self.category.HiddenPreviewsBodyPlaceholder = value
                    }
                }
            }

        form
            +++ Section(
                header: L10n.NotificationsConfigurator.Category.Rows.CategorySummary.header,
                footer: L10n.NotificationsConfigurator.Category.Rows.CategorySummary.footer
            ) {
                if category.isServerControlled {
                    $0.hidden = true
                }
            }

            <<< TextAreaRow {
                $0.tag = "categorySummaryFormat"
                if !newCategory, self.category.CategorySummaryFormat != "" {
                    $0.value = self.category.CategorySummaryFormat
                } else {
                    $0.value = L10n.NotificationsConfigurator.Category.Rows.CategorySummary.default
                }
            }.onChange { [realm] row in
                realm.reentrantWrite {
                    if let value = row.value {
                        self.category.CategorySummaryFormat = value
                    }
                }
            }

        form
            +++ MultivaluedSection(
                multivaluedOptions: defaultMultivalueOptions,
                header: L10n.NotificationsConfigurator.Category.Rows.Actions.header,
                footer: L10n.NotificationsConfigurator.Category.Rows.Actions.footer
            ) { section in
                if category.isServerControlled {
                    section.footer = nil
                }

                section.multivaluedRowToInsertAt = { index in

                    if index >= self.maxActionsForCategory - 1 {
                        section.multivaluedOptions = [.Reorder, .Delete]

                        self.addButtonRow.hidden = true

                        DispatchQueue.main.async { // I'm not sure why this is necessary
                            self.addButtonRow.evaluateHidden()
                        }
                    }

                    return self.getActionRow(nil)
                }

                section.addButtonProvider = { _ in
                    self.addButtonRow = ButtonRow {
                        $0.title = L10n.addButtonLabel
                        $0.cellStyle = .value1
                    }.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .left
                    }
                    return self.addButtonRow
                }

                for action in self.category.Actions {
                    section <<< self.getActionRow(action)
                }
            }

        form +++ YamlSection(
            tag: "exampleServiceCall",
            header: L10n.NotificationsConfigurator.Category.ExampleCall.title,
            yamlGetter: { [category] in category.exampleServiceCall },
            present: { [weak self] controller in self?.present(controller, animated: true, completion: nil) }
        )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)
        if let index = indexes.first?.section, let section = form.allSections[index] as? MultivaluedSection {
            let deletedIDs = rows.compactMap(\.tag)

            realm.reentrantWrite {
                // if the category isn't persisted yet, we need to remove the actions manually
                category.Actions.remove(
                    atOffsets: category.Actions
                        .enumerated()
                        .reduce(into: IndexSet()) { indexSet, val in
                            if deletedIDs.contains(val.element.Identifier) {
                                indexSet.insert(val.offset)
                            }
                        }
                )

                self.realm.delete(realm.objects(NotificationAction.self).filter("Identifier IN %@", deletedIDs))
            }

            if section.count < maxActionsForCategory {
                section.multivaluedOptions = defaultMultivalueOptions
                addButtonRow.hidden = false
                addButtonRow.evaluateHidden()
            }

            updatePreview()
        }
    }

    private func updatePreview() {
        if let section = form.sectionBy(tag: "exampleServiceCall") as? YamlSection {
            DispatchQueue.main.async {
                section.update()
            }
        }
    }

    override func valueHasBeenChanged(for row: BaseRow, oldValue: Any?, newValue: Any?) {
        super.valueHasBeenChanged(for: row, oldValue: oldValue, newValue: newValue)

        if row.section?.tag != "exampleServiceCall" {
            updatePreview()
        }
    }

    func getActionRow(_ existingAction: NotificationAction?) -> ButtonRowWithPresent<NotificationActionConfigurator> {
        var action = existingAction

        var identifier = "new_action_" + UUID().uuidString
        var title = L10n.NotificationsConfigurator.NewAction.title

        if let action = action {
            identifier = action.Identifier
            title = action.Title
        }

        return ButtonRowWithPresent<NotificationActionConfigurator> { row in
            row.tag = identifier
            row.title = title

            row.presentationMode = PresentationMode.show(controllerProvider: ControllerProvider.callback { [category] in
                NotificationActionConfigurator(category: category, action: action)
            }, onDismiss: { [realm, weak self] vc in
                vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? NotificationActionConfigurator {
                    // if the user goes to re-edit the action before saving the category, we want to show the same one
                    action = vc.action
                    row.tag = vc.action.Identifier
                    vc.row.title = vc.action.Title
                    vc.row.updateCell()
                    Current.Log.verbose("action \(vc.action)")

                    realm.reentrantWrite {
                        guard let self = self else { return }
                        // only add into realm if the category is also persisted
                        self.category.realm?.add(vc.action, update: .all)

                        if self.category.Actions.contains(vc.action) == false {
                            self.category.Actions.append(vc.action)
                        }
                    }

                    self?.updatePreview()
                }
            })
        }
    }

    @objc
    func getInfoAction(_ sender: Any) {
        openURLInBrowser(
            URL(string: "https://companion.home-assistant.io/app/ios/actionable-notifications")!,
            self
        )
    }

    @objc
    func save(_ sender: Any) {
        Current.Log.verbose("Go back hit, check for validation")

        Current.Log.verbose("Validate result \(form.validate())")
        if form.validate().count == 0 {
            Current.Log.verbose("Category form is valid, calling dismiss callback!")

            shouldSave = true

            onDismissCallback?(self)
        }
    }

    @objc
    func cancel(_ sender: Any) {
        Current.Log.verbose("Cancel hit, calling dismiss")

        shouldSave = false

        onDismissCallback?(self)
    }

    @objc
    func preview(_ sender: Any) {
        Current.Log.verbose("Preview hit")

        let content = UNMutableNotificationContent()
        content.title = L10n.NotificationsConfigurator.Category.PreviewNotification.title
        content.body = L10n.NotificationsConfigurator.Category.PreviewNotification.body(category.Name)
        content.sound = .default
        content.categoryIdentifier = category.Identifier
        content.userInfo = ["preview": true]

        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: category.Identifier,
            content: content,
            trigger: nil
        ))
    }
}
