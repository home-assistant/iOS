//
//  NotificationCategoryConfigurator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import UserNotifications
import RealmSwift
import Shared

class NotificationCategoryConfigurator: FormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?
    
    var category: NotificationCategory = NotificationCategory()
    var newCategory: Bool = true
    var allActions: [String: NotificationAction] = [:]

    private let realm = Current.realm()

    convenience init(category: NotificationCategory?) {
        self.init()
        if let category = category {
            self.category = category
            self.newCategory = false
        }
    }

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

        let saveSelector = #selector(NotificationCategoryConfigurator.save)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self,
                                                                 action: saveSelector)

        self.title = "Category Configurator"

        if newCategory == false {
            self.title = category.Name
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

        let existingActions = realm.objects(NotificationAction.self)
//        let existingActions = objs.sorted(byKeyPath: "Order")

        self.form
        +++ Section(header: "Settings", footer: "") {
            $0.tag = "settings"
        }

        <<< TextRow {
            $0.tag = "name"
            $0.title = "Name"
            $0.add(rule: RuleRequired())
            if !newCategory {
                $0.value = self.category.Name
            }
        }.onChange { row in
            if let value = row.value {
                self.category.Name = value
            }
        }

        <<< NotificationIdentifierRow {
            $0.tag = "identifier"
            $0.title = "Identifier"
            if !newCategory {
                $0.value = self.category.Identifier
            }
        }.onChange { row in
            if let value = row.value {
                self.category.Identifier = value
            }
        }

        if #available(iOS 11.0, *) {
        self.form
            +++ Section(header: "Hidden Preview Placeholder",
                        footer: "This text is only displayed if you have notification previews hidden. Use %u for the number of messages with the same thread identifier.")
            <<< TextAreaRow {
                $0.tag = "hiddenPreviewsBodyPlaceholder"
                $0.placeholder = "There are %u notifications."
                if !newCategory {
                    $0.value = self.category.HiddenPreviewsBodyPlaceholder
                }
            }.onChange { row in
                if let value = row.value {
                    self.category.HiddenPreviewsBodyPlaceholder = value
                }
            }
        }

        if #available(iOS 12.0, *) {
            self.form
                +++ Section(header: "Category Summary",
                            footer: "A format string for the summary description used when the system groups the category’s notifications.")
                <<< TextAreaRow {
                    $0.tag = "categorySummaryFormat"
                    if !newCategory {
                        $0.value = self.category.CategorySummaryFormat
                    }
                }.onChange { row in
                    if let value = row.value {
                        self.category.CategorySummaryFormat = value
                    }
                }
        }

        let mvOpts: MultivaluedOptions = [.Reorder, .Insert, .Delete]

        self.form
            +++ MultivaluedSection(multivaluedOptions: mvOpts, header: "Actions", footer: "") { section in
                    section.multivaluedRowToInsertAt = { index in
                        return self.getActionRow(nil)
                    }

                    for action in existingActions {
                        section <<< self.getActionRow(action)
                    }
                }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func getActionRow(_ action: NotificationAction?) -> ButtonRowWithPresent<NotificationActionConfigurator> {
        var identifier = "new_action_"+UUID().uuidString
        var title = "New Action"

        if let action = action {
            identifier = action.Identifier
            title = action.Title
        }

        return ButtonRowWithPresent<NotificationActionConfigurator> {
            $0.tag = identifier
            $0.title = title

            $0.presentationMode = PresentationMode.show(controllerProvider: ControllerProvider.callback {
                return NotificationActionConfigurator(action: action)
            }, onDismiss: { vc in
                vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? NotificationActionConfigurator {
                    vc.row.title = vc.action.Title
                    vc.row.updateCell()
                    self.allActions[vc.action.Identifier] = vc.action
                    print("action", vc.action)

                    // swiftlint:disable:next force_try
                    try! self.realm.write {
                        self.realm.add(vc.action, update: true)
                    }
                }

            })
        }
    }

//    override func viewDidDisappear(_ animated: Bool) {
//        if self.isBeingDismissed || self.isMovingFromParent {
//            var templateName = "UNKNOWN"
//
//            if let template = self.form.rowBy(tag: "template") as? PushRow<ComplicationTemplate>,
//                let value = template.value {
//                templateName = value.rawValue
//            }
//
//            var formVals = self.form.values(includeHidden: false)
//
//            for (key, val) in formVals {
//                if key.contains("color"), let color = val as? UIColor {
//                    formVals[key] = color.hexString(true)
//                }
//            }
//
//            formVals.removeValue(forKey: "template")
//
//            print("BYE BYE CONFIGURATOR", formVals)
//
//            let complication = WatchComplication()
//            complication.Family = self.family.rawValue
//            complication.Template = templateName
//            complication.Data = formVals as [String: Any]
//            print("COMPLICATION", complication)
//
//            let realm = Current.realm()
//
//            print("Realm is located at:", realm.configuration.fileURL!)
//
//
//            try! realm.write {
//                realm.add(complication, update: true)
//            }
//        }
//    }

    @objc
    func getInfoAction(_ sender: Any) {
        // FIXME: Actually open a modal window with docs!
        print("getInfoAction hit, open docs page!")
    }

    @objc
    func save(_ sender: Any) {
        print("Go back hit, check for validation")

        if self.form.validate().count == 0 {
            print("Category form is valid, calling dismiss callback!")

            self.category.Actions.removeAll()

            for action in self.allActions.map({ $1 }) {
                self.category.Actions.append(action)
            }

            onDismissCallback?(self)
        }
    }

}
