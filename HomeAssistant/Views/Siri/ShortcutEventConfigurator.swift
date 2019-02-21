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
import CleanroomLogger

@available(iOS 12, *)
class ShortcutEventConfigurator: FormViewController {

    // swiftlint:disable function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // Create the info button
        let infoButton = UIButton(type: .infoLight)

        // You will need to configure the target action for the button itself, not the bar button item
        infoButton.addTarget(self, action: #selector(getInfoAction), for: .touchUpInside)

        // Create a bar button item using the info button as its custom view
        let infoBarButtonItem = UIBarButtonItem(customView: infoButton)

        // Use it as required
        self.navigationItem.rightBarButtonItem = infoBarButtonItem

        self.title = "Fire Event"

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
            +++ Section(header: "Settings", footer: "") {
                $0.tag = "settings"
            }
            <<< TextRow("name") {
                $0.title = L10n.SiriShortcuts.Configurator.Settings.Name.title
                $0.add(rule: RuleRequired())
            }
            /*<<< SwitchRow("notifyOnRun") {
                $0.title = L10n.SiriShortcuts.Configurator.Settings.NotifyOnRun.title
            }*/

            +++ Section(header: "Configuration", footer: "") {
                $0.tag = "configuration"
            }

            <<< TextRow("event_name") {
                    $0.title = "Event name"
                    $0.add(rule: RuleRequired())
                }.cellUpdate { (cell, _) in
                    cell.textField.autocapitalizationType = .none
                    cell.textField.autocorrectionType = .no
                }

            <<< TextAreaRow("event_payload") {
                $0.title = "Event payload"
                $0.placeholder = "Must be valid JSON. If no payload is provided, clipboard contents will be used."
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
        Log.verbose?.message("getInfoAction hit, open docs page!")
    }
}

@available (iOS 12, *)
extension ShortcutEventConfigurator: INUIAddVoiceShortcutViewControllerDelegate {

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                        didFinishWith voiceShortcut: INVoiceShortcut?,
                                        error: Error?) {
        if let error = error as NSError? {
            Log.error?.message("Error adding voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }

        if let voiceShortcut = voiceShortcut {
            Log.verbose?.message("Shortcut with ID \(voiceShortcut.identifier.uuidString) added")
        }

        controller.dismiss(animated: true, completion: nil)
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

// MARK: - INUIEditVoiceShortcutViewControllerDelegate

@available (iOS 12, *)
extension ShortcutEventConfigurator: INUIEditVoiceShortcutViewControllerDelegate {

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didUpdate voiceShortcut: INVoiceShortcut?,
                                         error: Error?) {
        if let error = error as NSError? {
            Log.error?.message("Error updating voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }
        if let voiceShortcut = voiceShortcut {
            Log.verbose?.message("Shortcut with ID \(voiceShortcut.identifier.uuidString) updated")
        }
        controller.dismiss(animated: true, completion: nil)
        return
    }

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        Log.verbose?.message("Shortcut with ID \(deletedVoiceShortcutIdentifier.uuidString) deleted")
        controller.dismiss(animated: true, completion: nil)
        return
    }

    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
        return
    }
}
