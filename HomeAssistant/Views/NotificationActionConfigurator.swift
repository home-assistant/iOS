//
//  NotificationActionConfigurator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Shared
import Eureka
import RealmSwift

class NotificationActionConfigurator: FormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var newAction: Bool = true
    var action: NotificationAction = NotificationAction()

    private let realm = Current.realm()

    convenience init(action: NotificationAction?) {
        self.init()
        if let action = action {
            self.action = action
            self.newAction = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.title = action.Title

        if newAction {
            self.title = L10n.NotificationsConfigurator.NewAction.title
        }

        let saveSelector = #selector(NotificationActionConfigurator.save)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self,
                                                                 action: saveSelector)

        let infoButton = UIButton(type: .infoLight)

        infoButton.addTarget(self, action: #selector(NotificationActionConfigurator.getInfoAction),
                             for: .touchUpInside)

        let infoButtonView = UIBarButtonItem(customView: infoButton)

        let previewButton = UIBarButtonItem(withIcon: .eyeIcon, size: CGSize(width: 25, height: 25), target: self,
                                            action: #selector(NotificationActionConfigurator.preview))

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)

        self.setToolbarItems([infoButtonView, flexibleSpace, previewButton], animated: false)

        self.navigationController?.setToolbarHidden(false, animated: false)

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

        var footer = L10n.NotificationsConfigurator.Settings.footer

        if !self.newAction {
            footer = L10n.NotificationsConfigurator.Settings.Footer.idSet
        }

        self.form
        +++ Section(header: L10n.NotificationsConfigurator.Settings.header,
                    footer: footer)

        <<< TextRow {
                $0.tag = "title"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.Title.title
                $0.add(rule: RuleRequired())
                if !self.newAction {
                    $0.value = self.action.Title
                }
            }

        <<< NotificationIdentifierRow {
                $0.tag = "identifier"
                $0.title = L10n.NotificationsConfigurator.identifier
                if !self.newAction {
                    $0.disabled = true
                    $0.value = self.action.Identifier
                }
            }

        +++ Section()

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

        +++ Section(footer: L10n.NotificationsConfigurator.Action.Rows.Foreground.footer)
        <<< SwitchRow {
                $0.tag = "foreground"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.Foreground.title
                if !self.newAction {
                    $0.value = self.action.Foreground
                }
            }

        +++ Section(footer: L10n.NotificationsConfigurator.Action.Rows.Destructive.footer)
        <<< SwitchRow {
                $0.tag = "destructive"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.Destructive.title
                if !self.newAction {
                    $0.value = self.action.Destructive
                }
            }

        +++ Section(footer: L10n.NotificationsConfigurator.Action.Rows.AuthenticationRequired.footer)
        <<< SwitchRow {
                $0.tag = "authenticationRequired"
                $0.title = L10n.NotificationsConfigurator.Action.Rows.AuthenticationRequired.title
                if !self.newAction {
                    $0.value = self.action.AuthenticationRequired
                }
            }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc
    func getInfoAction(_ sender: Any) {
        Current.Log.verbose("getInfoAction hit, open docs page!")
    }

    @objc
    func save(_ sender: Any) {
        Current.Log.verbose("Go back hit, check for validation")

        if self.form.validate().count == 0 {
            Current.Log.verbose("Action form is valid, saving Action")

            let formVals = self.form.values(includeHidden: true)

            // swiftlint:disable:next force_try
            try! realm.write {
                // swiftlint:disable force_cast
                if self.newAction {
                    self.action.Identifier = formVals["identifier"] as! String
                }

                self.action.Title = formVals["title"] as! String
                self.action.TextInput = formVals["textInput"] as? Bool ?? false
                self.action.TextInputButtonTitle = formVals["textInputButtonTitle"] as? String
                self.action.TextInputPlaceholder = formVals["textInputPlaceholder"] as? String

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

}
