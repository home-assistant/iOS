import Eureka
import Foundation
import RealmSwift
import Shared
import UIKit

class NotificationActionConfigurator: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    private let category: NotificationCategory
    var newAction: Bool = true
    var action = NotificationAction()

    private let realm = Current.realm()

    init(category: NotificationCategory, action: NotificationAction?) {
        self.category = category
        super.init()

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }

        if let action = action {
            self.action = action
            self.newAction = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        title = action.Title

        if newAction {
            title = L10n.NotificationsConfigurator.NewAction.title
        }

        if !action.isServerControlled {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancel)
            )

            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .save,
                target: self,
                action: #selector(save(_:))
            )
        }

        TextRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        SwitchRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

//        let existingActionIDs = Array(Current.realm().objects(NotificationAction.self).map({ $0.Identifier }))

        let footer: String?

        if action.isServerControlled {
            footer = nil
        } else if newAction {
            footer = L10n.NotificationsConfigurator.Settings.footer
        } else {
            footer = L10n.NotificationsConfigurator.Settings.Footer.idSet
        }

        form
            +++ Section(
                header: L10n.NotificationsConfigurator.Settings.header,
                footer: footer
            )

            <<< TextRow {
                $0.tag = "title"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.Title.title
                $0.add(rule: RuleRequired())
                if action.isServerControlled {
                    $0.disabled = true
                }
                if !self.newAction {
                    $0.value = self.action.Title
                }
            }

            <<< NotificationIdentifierRow {
                $0.tag = "identifier"
                $0.title = L10n.NotificationsConfigurator.identifier
                $0.uppercaseOnly = true
                if !self.newAction {
                    $0.disabled = true
                    $0.value = self.action.Identifier
                }
            }

            +++ Section {
                if self.action.isServerControlled {
                    $0.hidden = true
                }
            }

            <<< SwitchRow {
                $0.tag = "textInput"
                $0.title = L10n.NotificationsConfigurator.Action.TextInput.title
                if !self.newAction {
                    $0.value = self.action.TextInput
                }
            }.onChange { row in
                if let value = row.value {
                    if let buttonTitle = self.form.rowBy(tag: "textInputButtonTitle") {
                        buttonTitle.hidden = Condition(booleanLiteral: !value)
                        buttonTitle.evaluateHidden()
                    }
                    if let placeholder = self.form.rowBy(tag: "textInputPlaceholder") {
                        placeholder.hidden = Condition(booleanLiteral: !value)
                        placeholder.evaluateHidden()
                    }
                }
            }

            <<< TextRow {
                $0.tag = "textInputButtonTitle"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.TextInputButtonTitle.title
                $0.hidden = Condition(booleanLiteral: !self.action.TextInput)
                $0.add(rule: RuleRequired())
                if !self.newAction {
                    $0.value = self.action.TextInputButtonTitle
                }
            }

            <<< TextRow {
                $0.tag = "textInputPlaceholder"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.TextInputPlaceholder.title
                $0.hidden = Condition(booleanLiteral: !self.action.TextInput)
                $0.add(rule: RuleRequired())
                if !self.newAction {
                    $0.value = self.action.TextInputPlaceholder
                }
            }

            +++ Section(
                footer: L10n.NotificationsConfigurator.Action.Rows.Foreground.footer
            ) {
                if action.isServerControlled {
                    $0.hidden = true
                }
            }

            <<< SwitchRow {
                $0.tag = "foreground"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.Foreground.title
                if !self.newAction {
                    $0.value = self.action.Foreground
                }
            }

            +++ Section(
                footer: L10n.NotificationsConfigurator.Action.Rows.Destructive.footer
            ) {
                if action.isServerControlled {
                    $0.hidden = true
                }
            }

            <<< SwitchRow {
                $0.tag = "destructive"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.Destructive.title
                if !self.newAction {
                    $0.value = self.action.Destructive
                }
            }

            +++ Section(
                footer: L10n.NotificationsConfigurator.Action.Rows.AuthenticationRequired.footer
            ) {
                if action.isServerControlled {
                    $0.hidden = true
                }
            }
            <<< SwitchRow {
                $0.tag = "authenticationRequired"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.AuthenticationRequired.title
                if !self.newAction {
                    $0.value = self.action.AuthenticationRequired
                }
            }

            +++ YamlSection(
                tag: "exampleTrigger",
                header: L10n.ActionsConfigurator.TriggerExample.title,
                yamlGetter: { [weak form, category] in
                    guard let form = form else { return "" }

                    let formVals = form.values(includeHidden: true)

                    if let anyApi = Current.apis.first {
                        return NotificationAction.exampleTrigger(
                            api: anyApi,
                            identifier: formVals["identifier"] as? String ?? "",
                            category: category.Identifier,
                            textInput: formVals["textInput"] as? Bool ?? false
                        )
                    } else {
                        return ""
                    }
                },
                present: { [weak self] controller in self?.present(controller, animated: true, completion: nil) }
            )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc
    func save(_ sender: Any) {
        Current.Log.verbose("Go back hit, check for validation")

        if form.validate().count == 0 {
            Current.Log.verbose("Action form is valid, saving Action")

            let formVals = form.values(includeHidden: true)

            realm.reentrantWrite {
                // swiftlint:disable force_cast
                if self.newAction {
                    self.action.Identifier = formVals["identifier"] as! String
                }

                self.action.Title = formVals["title"] as! String
                self.action.TextInput = formVals["textInput"] as? Bool ?? false
                if let buttonTitle = formVals["textInputButtonTitle"] as? String {
                    self.action.TextInputButtonTitle = buttonTitle
                }
                if let inputPlaceholder = formVals["textInputPlaceholder"] as? String {
                    self.action.TextInputPlaceholder = inputPlaceholder
                }

                if let foreground = formVals["foreground"] as? Bool {
                    self.action.Foreground = foreground
                }

                if let destructive = formVals["destructive"] as? Bool {
                    self.action.Destructive = destructive
                }

                if let authenticationRequired = formVals["authenticationRequired"] as? Bool {
                    self.action.AuthenticationRequired = authenticationRequired
                }
            }

            onDismissCallback?(self)
        }
    }

    @objc
    func preview(_ sender: Any) {
        Current.Log.verbose("Preview hit")
    }

    override func valueHasBeenChanged(for row: BaseRow, oldValue: Any?, newValue: Any?) {
        super.valueHasBeenChanged(for: row, oldValue: oldValue, newValue: newValue)

        if let section = form.sectionBy(tag: "exampleTrigger") as? YamlSection, row.section != section {
            section.update()
        }
    }
}
