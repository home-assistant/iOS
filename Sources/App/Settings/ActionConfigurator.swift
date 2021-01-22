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
import ColorPickerRow
import ViewRow
import PromiseKit

class ActionConfigurator: FormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var action: Action = Action() {
        didSet {
            self.updatePreviews()
        }
    }
    var newAction: Bool = true
    var shouldSave: Bool = false
    var preview = ActionPreview(frame: CGRect(x: 0, y: 0, width: 169, height: 44))

    convenience init(action: Action?) {
        self.init()

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }

        if let action = action {
            self.action = Action(value: action)
            self.newAction = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

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

        let firstSection = Section()
        form +++ firstSection

        firstSection <<< TextRow {
            $0.tag = "name"
            $0.title = L10n.ActionsConfigurator.Rows.Name.title
            $0.placeholder = L10n.ActionsConfigurator.Rows.Name.title
            $0.add(rule: RuleRequired())
            $0.disabled = .init(booleanLiteral: !action.canConfigure(\Action.Name))
            if !newAction {
                $0.value = self.action.Name
            }
        }.onChange { row in
            if let value = row.value {
                self.action.Name = value
                self.updatePreviews()
            }
        }

        let visuals = Section(

        )

        if action.canConfigure(\Action.Text) || action.isServerControlled {
            let section: Section

            if action.canConfigure(\Action.Text) {
                section = visuals
            } else {
                section = firstSection
            }

            section <<< TextRow("text") {
                $0.title = L10n.ActionsConfigurator.Rows.Text.title
                $0.value = self.action.Text
                $0.placeholder = L10n.ActionsConfigurator.Rows.Text.title
                $0.add(rule: RuleRequired())
                $0.disabled = .init(booleanLiteral: !action.canConfigure(\Action.Text))
            }.onChange { row in
                if let value = row.value {
                    self.action.Text = value
                    self.updatePreviews()
                }
            }
        }

        if #available(iOS 13.0, *) {
            // after text if uneditable
            firstSection <<< VoiceShortcutRow {
                $0.buttonStyle = .automaticOutline
                $0.value = .intent(PerformActionIntent(action: action))
            }
        }

        if action.canConfigure(\Action.TextColor) {
            visuals <<< InlineColorPickerRow("text_color") {
                $0.title = L10n.ActionsConfigurator.Rows.TextColor.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor(hex: self.action.TextColor)
            }.onChange { row in
                if let value = row.value {
                    self.action.TextColor = value.hexString()
                    self.updatePreviews()
                }
            }
        }

        if action.canConfigure(\Action.BackgroundColor) {
            visuals <<< InlineColorPickerRow("background_color") {
                $0.title = L10n.ActionsConfigurator.Rows.BackgroundColor.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor(hex: self.action.BackgroundColor)

            }.onChange { row in
                if let value = row.value {
                    self.action.BackgroundColor = value.hexString()
                    self.updatePreviews()
                }
            }
        }

        if action.canConfigure(\Action.IconName) {
            visuals <<< SearchPushRow<MaterialDesignIcons> {
                $0.options = MaterialDesignIcons.allCases
                $0.selectorTitle = L10n.ActionsConfigurator.Rows.Icon.title
                $0.tag = "icon"
                $0.title = L10n.ActionsConfigurator.Rows.Icon.title
                $0.value = MaterialDesignIcons(named: self.action.IconName)
                $0.displayValueFor = { icon in
                    icon?.name
                }
            }.cellUpdate({ (cell, row) in
                if let value = row.value {
                    cell.imageView?.image = value.image(
                        ofSize: CGSize(width: CGFloat(30), height: CGFloat(30)),
                        color: .black
                    ).withRenderingMode(.alwaysTemplate)
                }
            }).onPresent { _, to in
                to.selectableRowCellUpdate = { cell, row in
                    if let value = row.selectableValue {
                        cell.imageView?.image = value.image(
                            ofSize: CGSize(width: CGFloat(30), height: CGFloat(30)),
                            color: .systemGray
                        ).withRenderingMode(.alwaysTemplate)
                        cell.textLabel?.text = value.name
                    }
                }
            }.onChange { row in
                if let value = row.value {
                    self.action.IconName = value.name
                    self.updatePreviews()
                }
            }
        }

        if action.canConfigure(\Action.IconColor) {
            visuals <<< InlineColorPickerRow("icon_color") {
                $0.title = L10n.ActionsConfigurator.Rows.IconColor.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor(hex: self.action.IconColor)
            }.onChange { (picker) in
                Current.Log.verbose("icon color: \(picker.value!.hexString(false))")

                self.action.IconColor = picker.value!.hexString()

                self.updatePreviews()
            }
        }

        if visuals.isEmpty {
            form +++ InfoLabelRow {
                switch action.triggerType {
                case .event:
                    $0.title = L10n.ActionsConfigurator.VisualSection.serverDefined
                case .scene:
                    $0.title = L10n.ActionsConfigurator.VisualSection.sceneDefined
                }
            }
        } else {
            // only show cancel/save flow for editable actions
            navigationItem.leftBarButtonItems = [
                UIBarButtonItem(
                    barButtonSystemItem: .cancel,
                    target: self,
                    action: #selector(cancel)
                )
            ]

            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(
                    barButtonSystemItem: .save,
                    target: self,
                    action: #selector(save)
                )
            ]

            if action.triggerType == .scene {
                let keys = [Scene.textColorKey, Scene.backgroundColorKey, Scene.iconColorKey]
                let list: String

                if #available(iOS 13, *) {
                    list = ListFormatter.localizedString(byJoining: keys)
                } else {
                    list = keys.joined(separator: ", ")
                }

                visuals.footer = HeaderFooterView(
                    stringLiteral: L10n.ActionsConfigurator.VisualSection.sceneHintFooter(list)
                )
            }

            form.append(visuals)
        }

        form +++ ViewRow<ActionPreview>("preview").cellSetup { (cell, _) in
            cell.backgroundColor = UIColor.clear
            cell.preservesSuperviewLayoutMargins = false
            self.updatePreviews()
            cell.view = self.preview
        }

        form +++ YamlSection(
            tag: "exampleTrigger",
            header: L10n.ActionsConfigurator.TriggerExample.title,
            yamlGetter: { [action] in action.exampleTrigger },
            present: { [weak self] controller in self?.present(controller, animated: true, completion: nil) }
        )
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
            Current.Log.verbose("Category form is valid, calling dismiss callback!")

            self.shouldSave = true

            onDismissCallback?(self)
        }
    }

    @objc
    func cancel(_ sender: Any) {
        Current.Log.verbose("Cancel hit, calling dismiss")

        self.shouldSave = false

        onDismissCallback?(self)
    }

    private func updatePreviews() {
        if action.Name.isEmpty && newAction {
            title = L10n.ActionsConfigurator.title
        } else {
            title = action.Name
        }

        preview.setup(action)

        if let section = form.sectionBy(tag: "exampleTrigger") as? YamlSection {
            section.update()
        }
    }
}

class ActionPreview: UIView {
    var imageView = UIImageView(frame: CGRect(x: 15, y: 0, width: 44, height: 44))
    var title = UILabel(frame: CGRect(x: 60, y: 60, width: 200, height: 100))
    var action: Action?

    override func layoutSubviews() {
        super.layoutSubviews()

        self.layer.cornerRadius = 5.0

        self.layer.cornerRadius = 2.0
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.clear.cgColor
        self.layer.masksToBounds = true

        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2.0)
        self.layer.shadowRadius = 2.0
        self.layer.shadowOpacity = 0.5
        self.layer.masksToBounds = false
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.layer.cornerRadius).cgPath

        let centerY = (self.frame.size.height / 2) - 50

        self.title = UILabel(frame: CGRect(x: 60, y: centerY, width: 200, height: 100))

        self.title.textAlignment = .natural
        self.title.clipsToBounds = true
        self.title.numberOfLines = 1
        self.title.font = self.title.font.withSize(UIFont.smallSystemFontSize)

        self.addSubview(self.title)
        self.addSubview(self.imageView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleGesture))
        self.addGestureRecognizer(tap)
    }

    public func setup(_ action: Action) {
        self.action = action
        DispatchQueue.main.async {
            self.backgroundColor = UIColor(hex: action.BackgroundColor)

            let icon = MaterialDesignIcons.init(named: action.IconName)
            self.imageView.image = icon.image(ofSize: self.imageView.bounds.size,
                                              color: UIColor(hex: action.IconColor))
            self.title.text = action.Text
            self.title.textColor = UIColor(hex: action.TextColor)
        }
    }

    @objc func handleGesture(gesture: UITapGestureRecognizer) {
        guard let action = action else { return }

        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()

        self.imageView.showActivityIndicator()

        Current.api.then { api in
            api.HandleAction(actionID: action.ID, source: .Preview)
        }.done { _ in
            feedbackGenerator.notificationOccurred(.success)
        }.ensure {
            self.imageView.hideActivityIndicator()
        }.catch { err -> Void in
            Current.Log.error("Error during action event fire: \(err)")
            feedbackGenerator.notificationOccurred(.error)
        }
    }
}
