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

    convenience init(action: NotificationAction?) {
        self.init()
        if let action = action {
            self.action = action
            self.newAction = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // Create the info button
        let infoButton = UIButton(type: .infoLight)

        // You will need to configure the target action for the button itself, not the bar button item
        infoButton.addTarget(self, action: #selector(NotificationActionConfigurator.getInfoAction), for: .touchUpInside)

        // Create a bar button item using the info button as its custom view
        let infoBarButtonItem = UIBarButtonItem(customView: infoButton)

        // Use it as required
        self.navigationItem.leftBarButtonItem = infoBarButtonItem

        self.title = action.Title

        if newAction {
            self.title = "New Action"
        }

        let saveSelector = #selector(NotificationActionConfigurator.save)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self,
                                                                 action: saveSelector)

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

        let existingActionIDs = Array(Current.realm().objects(NotificationAction.self).map({ $0.Identifier }))

        self.form
        +++ Section(header: "Settings", footer: "") {
            $0.tag = "settings"
        }

        <<< TextRow {
                $0.tag = "title"
                $0.title = "Title"
                $0.add(rule: RuleRequired())
                if !self.newAction {
                    $0.value = self.action.Title
                }
            }.onChange { row in
                if let value = row.value {
                    self.action.Title = value
                }
            }

        <<< NotificationIdentifierRow {
                $0.tag = "identifier"
                $0.title = "Identifier"
                if !self.newAction {
                    $0.value = self.action.Identifier
                }
            }.onChange { row in
                if let value = row.value {
                    if existingActionIDs.contains(value) {
                        print("DUPLICATE ACTION IDENTIFIER!", value)
                    } else {
                        self.action.Identifier = value
                    }
                }
            }

        <<< SwitchRow {
            $0.tag = "textInput"
            $0.title = "Text Input"
            if !self.newAction {
                $0.value = self.action.TextInput
            }
        }.onChange { row in
            if let value = row.value {
                self.action.TextInput = value
                if let textInputSection = self.form.sectionBy(tag: "text_input") {
                    textInputSection.hidden = Condition(booleanLiteral: !value)
                    textInputSection.evaluateHidden()
                }
            }
        }

        +++ Section(header: "Text Input", footer: "") {
            $0.tag = "text_input"
            $0.hidden = Condition(booleanLiteral: !self.action.TextInput)
        }

        <<< TextRow {
            $0.tag = "textInputButtonTitle"
            $0.title = "Button Title"
            $0.add(rule: RuleRequired())
            if !self.newAction {
                $0.value = self.action.TextInputButtonTitle
            }
            }.onChange { row in
                if let value = row.value {
                    self.action.TextInputButtonTitle = value
                }
        }

        <<< TextRow {
            $0.tag = "textInputPlaceholder"
            $0.title = "Placeholder"
            $0.add(rule: RuleRequired())
            if !self.newAction {
                $0.value = self.action.TextInputPlaceholder
            }
            }.onChange { row in
                if let value = row.value {
                    self.action.TextInputPlaceholder = value
                }
        }

        +++ Section(header: "Options", footer: "")

        <<< SwitchRow {
                $0.tag = "foreground"
                $0.title = "Launch app"
                if !self.newAction {
                    $0.value = self.action.Foreground
                }
            }.onChange { row in
                if let value = row.value {
                    self.action.Foreground = value
                }
            }

        <<< SwitchRow {
                $0.tag = "destructive"
                $0.title = "Action is destructive"
                if !self.newAction {
                    $0.value = self.action.Destructive
                }
            }.onChange { row in
                if let value = row.value {
                    self.action.Destructive = value
                }
            }

        <<< SwitchRow {
                $0.tag = "authenticationRequired"
                $0.title = "Authentication is required"
                if !self.newAction {
                    $0.value = self.action.AuthenticationRequired
                }
            }.onChange { row in
                if let value = row.value {
                    self.action.AuthenticationRequired = value
                }
            }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc
    func getInfoAction(_ sender: Any) {
        // FIXME: Actually open a modal window with docs!
        print("getInfoAction hit, open docs page!")
    }

    @objc
    func save(_ sender: Any) {
        print("Go back hit, check for validation")

        if self.form.validate().count == 0 {
            print("Action form is valid, calling dismiss callback!")
            onDismissCallback?(self)
        }
    }

}
