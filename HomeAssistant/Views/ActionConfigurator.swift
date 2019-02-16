//
//  ActionConfigurator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import RealmSwift
import Shared
import Iconic
import ColorPickerRow

class ActionConfigurator: FormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var action: Action = Action()
    var newAction: Bool = true
    var shouldSave: Bool = false

    private let realm = Current.realm()

    convenience init(action: Action?) {
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

        let cancelSelector = #selector(ActionConfigurator.cancel)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self,
                                                                 action: cancelSelector)

        let saveSelector = #selector(ActionConfigurator.save)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self,
                                                                 action: saveSelector)

        let infoButton = UIButton(type: .infoLight)

        infoButton.addTarget(self, action: #selector(ActionConfigurator.getInfoAction),
                             for: .touchUpInside)

        let infoButtonView = UIBarButtonItem(customView: infoButton)

        self.setToolbarItems([infoButtonView], animated: false)

        self.navigationController?.setToolbarHidden(false, animated: false)

        self.title = "New Action"

        if newAction == false {
            self.title = action.Name
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

        self.form
            +++ Section()

            <<< TextRow {
                    $0.tag = "name"
                    $0.title = L10n.NotificationsConfigurator.Category.Rows.Name.title
                    $0.add(rule: RuleRequired())
                    if !newAction {
                        $0.value = self.action.Name
                    }
            }.onChange { row in
                if let value = row.value {
                    self.action.Name = value
                }
            }

            <<< InlineColorPickerRow("background_color") {
                $0.title = "Background Color"
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor(hex: self.action.BackgroundColor)
            }.onChange { row in
                if let value = row.value {
                    self.action.BackgroundColor = value.hexString()
                }
            }

            +++ Section()
            <<< TextRow {
                $0.title = "Text"
            }

            <<< InlineColorPickerRow("text_color") {
                    $0.title = "Text Color"
                    $0.isCircular = true
                    $0.showsPaletteNames = true
                    $0.value = UIColor(hex: self.action.TextColor)
            }.onChange { row in
                if let value = row.value {
                    self.action.TextColor = value.hexString()
                }
            }

            +++ Section()
            <<< PushRow<String> {
                    $0.options = MaterialDesignIcons.allCases.map({ $0.name })
                    $0.selectorTitle = "Icon"
                    $0.tag = "icon"
                    $0.title = "Icon"
                }.cellUpdate({ (cell, row) in
                    if let value = row.value {
                        let theIcon = MaterialDesignIcons(named: value)
                        if let iconColorRow = self.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                            cell.imageView?.image = theIcon.image(ofSize: CGSize(width: CGFloat(30),
                                                                                 height: CGFloat(30)),
                                                                  color: iconColorRow.value)
                        }
                    }
                }).onPresent { _, to in
                    to.selectableRowCellSetup = {cell, row in
                        if let value = row.selectableValue {
                            let theIcon = MaterialDesignIcons(named: value)
                            cell.imageView?.image = theIcon.image(ofSize: CGSize(width: CGFloat(30),
                                                                                 height: CGFloat(30)),
                                                                  color: .black)
                        }
                    }
                    to.selectableRowCellUpdate = { cell, row in
                        cell.textLabel?.text = row.selectableValue!
                    }
                }.onChange { row in
                    if let value = row.value {
                        self.action.IconName = value
                    }
            }

            <<< InlineColorPickerRow("icon_color") {
                    $0.title = "Icon Color"
                    $0.isCircular = true
                    $0.showsPaletteNames = true
                    $0.value = UIColor.green
                    $0.value = UIColor(hex: self.action.IconColor)
                }.onChange { (picker) in
                    print("icon color: \(picker.value!.hexString(false))")

                    self.action.IconColor = picker.value!.hexString()

                    if let iconRow = self.form.rowBy(tag: "icon") as? PushRow<String> {
                        if let value = iconRow.value {
                            let theIcon = MaterialDesignIcons(named: value)
                            iconRow.cell.imageView?.image = theIcon.image(ofSize: CGSize(width: CGFloat(30),
                                                                                         height: CGFloat(30)),
                                                                          color: picker.value)
                        }
                    }
            }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc
    func getInfoAction(_ sender: Any) {
        print("getInfoAction hit, open docs page!")
    }

    @objc
    func save(_ sender: Any) {
        print("Go back hit, check for validation")

        if self.form.validate().count == 0 {
            print("Category form is valid, calling dismiss callback!")

            self.shouldSave = true

            onDismissCallback?(self)
        }
    }

    @objc
    func cancel(_ sender: Any) {
        print("Cancel hit, calling dismiss")

        self.shouldSave = false

        onDismissCallback?(self)
    }

}
