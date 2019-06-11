//
//  ShortcutEventConfigurator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/13/19.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import Shared
import Intents
import IntentsUI
import PromiseKit
import ObjectMapper
import ViewRow

class ShortcutEventConfigurator: FormViewController {

    // swiftlint:disable function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let infoBarButtonItem = Constants.helpBarButtonItem

        infoBarButtonItem.action = #selector(getInfoAction)
        infoBarButtonItem.target = self

        // Use it as required
        self.navigationItem.rightBarButtonItem = infoBarButtonItem

        self.title = L10n.SiriShortcuts.Intents.FireEvent.title

        PickerInlineRow<String>.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        TextRow.defaultCellUpdate = { cell, row in
            cell.textField.clearButtonMode = .whileEditing
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        TextAreaRow.defaultCellSetup = { cell, row in
            cell.textView.smartQuotesType = .no
            cell.textView.smartDashesType = .no
        }

        TextAreaRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.placeholderLabel?.textColor = .red
            }
        }

        IntRow.defaultCellUpdate = { cell, row in
            cell.textField.clearButtonMode = .whileEditing
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        DecimalRow.defaultCellUpdate = { cell, row in
            cell.textField.clearButtonMode = .whileEditing
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        SwitchRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        self.form
            +++ Section(header: L10n.SiriShortcuts.Configurator.Settings.header, footer: "") {
                $0.tag = "settings"
            }
            <<< TextRow("name") {
                $0.title = L10n.SiriShortcuts.Configurator.Settings.Name.title
                $0.add(rule: RuleRequired())
            }
            /*<<< SwitchRow("notifyOnRun") {
                $0.title = L10n.SiriShortcuts.Configurator.Settings.NotifyOnRun.title
            }*/

            +++ Section(header: L10n.SiriShortcuts.Configurator.FireEvent.Configuration.header, footer: "") {
                $0.tag = "configuration"
            }

            <<< TextRow("event_name") {
                    $0.title = L10n.SiriShortcuts.Configurator.FireEvent.Rows.Name.title
                    $0.add(rule: RuleRequired())
                }.cellUpdate { (cell, _) in
                    cell.textField.autocapitalizationType = .none
                    cell.textField.autocorrectionType = .no
                }

            <<< TextAreaRow("event_payload") {
                $0.title = L10n.SiriShortcuts.Configurator.FireEvent.Rows.Payload.title
                $0.placeholder = L10n.SiriShortcuts.Configurator.FireEvent.Rows.Payload.placeholder
            }

        self.form
            +++ Section {
                $0.tag = "add_to_siri"
            }
            <<< ViewRow<UIView> {
                    $0.tag = "add_to_siri"
                }.cellSetup { (cell, _) in
                    cell.backgroundColor = UIColor.clear
                    cell.preservesSuperviewLayoutMargins = false

                    //  Construct the view for the cell
                    cell.view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

                    let button = INUIAddVoiceShortcutButton(style: .blackOutline)
                    button.translatesAutoresizingMaskIntoConstraints = false

                    cell.view?.addSubview(button)

                    cell.view?.centerXAnchor.constraint(equalTo: button.centerXAnchor).isActive = true
                    cell.view?.centerYAnchor.constraint(equalTo: button.centerYAnchor).isActive = true

                    button.addTarget(self, action: #selector(self.addToSiri(_:)), for: .touchUpInside)
                }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc
    func addToSiri(_ sender: Any) {

        let validationResult = self.form.validate()
        if validationResult.count == 0 {
            guard let eventNameRow = self.form.rowBy(tag: "event_name") as? TextRow,
                let eventName = eventNameRow.value else { return }

            var eventIntent = FireEventIntent(eventName: eventName)

            if let eventPayloadRow = self.form.rowBy(tag: "event_payload") as? TextAreaRow,
                let eventPayload = eventPayloadRow.value {
                eventIntent = FireEventIntent(eventName: eventName, payload: eventPayload)
            }

            if let shortcut = INShortcut(intent: eventIntent) {
                let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
                viewController.modalPresentationStyle = .formSheet
                viewController.delegate = self
                present(viewController, animated: true, completion: nil)
            }
        }
    }

    @objc
    func getInfoAction(_ sender: Any) {
        Current.Log.verbose("getInfoAction hit, open docs page!")
    }
}

extension ShortcutEventConfigurator: INUIAddVoiceShortcutViewControllerDelegate {

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                        didFinishWith voiceShortcut: INVoiceShortcut?,
                                        error: Error?) {
        if let error = error as NSError? {
            Current.Log.error("Error adding voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }

        if let voiceShortcut = voiceShortcut {
            Current.Log.verbose("Shortcut with ID \(voiceShortcut.identifier.uuidString) added")
        }

        controller.dismiss(animated: true, completion: nil)
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

// MARK: - INUIEditVoiceShortcutViewControllerDelegate

extension ShortcutEventConfigurator: INUIEditVoiceShortcutViewControllerDelegate {

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didUpdate voiceShortcut: INVoiceShortcut?,
                                         error: Error?) {
        if let error = error as NSError? {
            Current.Log.error("Error updating voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }
        if let voiceShortcut = voiceShortcut {
            Current.Log.verbose("Shortcut with ID \(voiceShortcut.identifier.uuidString) updated")
        }
        controller.dismiss(animated: true, completion: nil)
        return
    }

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        Current.Log.verbose("Shortcut with ID \(deletedVoiceShortcutIdentifier.uuidString) deleted")
        controller.dismiss(animated: true, completion: nil)
        return
    }

    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
        return
    }
}
