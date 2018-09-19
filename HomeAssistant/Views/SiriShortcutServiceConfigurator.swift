//
//  SiriShortcutServiceConfigurator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/17/18.
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

@available(iOS 12, *)
class SiriShortcutServiceConfigurator: FormViewController {

    var domain: String = "homeassistant"
    var serviceName: String = "check_config"
    var serviceData: ServiceDefinition?
    var entityIDs: [String] = []

    var serviceDataJSON: String?

    // swiftlint:disable cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.title = domain + "." + serviceName

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self,
                                                                 action: #selector(addToSiri))

        PickerInlineRow<String>.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.backgroundColor = .red
            }
        }

        TextAreaRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.backgroundColor = .red
            }
        }

        IntRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.titleLabel?.textColor = .red
            }
        }

        DecimalRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.titleLabel?.textColor = .red
            }
        }

        SwitchRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        if let service = serviceData {
            for (key, field) in service.Fields {
                var footer = ""
                var optionalField = false
                if let desc = field.Description {
                    footer = desc
                    if desc.lowercased().range(of: "optional") != nil {
                        optionalField = true
                    }
                }

                if let example = field.Example {
                    footer += " Suggested: \(example)"
                }

                self.form +++ Section(header: "", footer: footer)

                if key == "entity_id" {
                    self.form.last! <<< PickerInlineRow<String> {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }

                        var sortedEntityIDs = entityIDs

                        if let wantedEntityID = field.Example as? String {
                            let wantedDomain = wantedEntityID.components(separatedBy: ".")[0]
                            let wantedIDs = entityIDs.filter {
                                wantedDomain == $0.components(separatedBy: ".")[0]
                            }.sorted()
                            let notWantedIDs = entityIDs.filter {
                                wantedDomain != $0.components(separatedBy: ".")[0]
                            }.sorted()
                            sortedEntityIDs = wantedIDs + notWantedIDs
                        }

                        $0.options = sortedEntityIDs
                    }
                } else if let example = field.Example as? String {
                    self.form.last! <<< TextRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        $0.placeholder = example
                        if let defaultValue = field.Default, let defaultValueStr = defaultValue as? String {
                            $0.value = defaultValueStr
                        }
                    }
                } else if let example = field.Example as? Int {
                    self.form.last! <<< IntRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        $0.placeholder = example.description
                        if let defaultValue = field.Default, let defaultValueInt = defaultValue as? Int {
                            $0.value = defaultValueInt
                        }
                    }
                } else if let example = field.Example as? Double {
                    self.form.last! <<< DecimalRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        $0.placeholder = example.description
                        if let defaultValue = field.Default, let defaultValueDouble = defaultValue as? Double {
                            $0.value = defaultValueDouble
                        }
                    }
                } else if let example = field.Example as? Bool {
                    self.form.last! <<< SwitchRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        if let defaultValue = field.Default, let defaultValueBool = defaultValue as? Bool {
                            $0.value = defaultValueBool
                        } else {
                            $0.value = example
                        }
                    }
                } else {
                    self.form.last! <<< TextRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        if let defaultValue = field.Default, let defaultValueStr = defaultValue as? String {
                            $0.value = defaultValueStr
                        }
                    }
                }
            }
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
            let formData = form.values()
            let jsonData = try? JSONSerialization.data(withJSONObject: formData, options: [])
            let jsonString = String(data: jsonData!, encoding: .utf8)

            let serviceIntent = CallServiceIntent()
            serviceIntent.domain = domain
            serviceIntent.service = serviceName
            serviceIntent.data = jsonString

            let intentJSONData = try? JSONSerialization.data(withJSONObject: ["domain": domain,
                                                                              "service": serviceName,
                                                                              "data": formData],
                                                             options: [])
            serviceDataJSON = String(data: intentJSONData!, encoding: .utf8)

            if let shortcut = INShortcut(intent: serviceIntent) {
                let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
                viewController.modalPresentationStyle = .formSheet
                viewController.delegate = self
                present(viewController, animated: true, completion: nil)
            }
        }
    }
}

@available (iOS 12, *)
extension SiriShortcutServiceConfigurator: INUIAddVoiceShortcutViewControllerDelegate {

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                        didFinishWith voiceShortcut: INVoiceShortcut?,
                                        error: Error?) {
        if let error = error {
            print("error adding voice shortcut:\(error.localizedDescription)")
            return
        }

        if let voiceShortcut = voiceShortcut {
            print("UPDATE SHORTCUTS 3")

            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                realm.add(SiriShortcut(intent: "CallService", shortcut: voiceShortcut, jsonData: serviceDataJSON))
            }
            dismiss(animated: true, completion: nil)
            self.dismiss(animated: true, completion: nil)
        }
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - INUIEditVoiceShortcutViewControllerDelegate

@available (iOS 12, *)
extension SiriShortcutServiceConfigurator: INUIEditVoiceShortcutViewControllerDelegate {

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didUpdate voiceShortcut: INVoiceShortcut?,
                                         error: Error?) {
        if let error = error {
            print("error adding voice shortcut:\(error.localizedDescription)")
            return
        }
        print("UPDATE SHORTCUTS HERE 1")
    }

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        print("UPDATE SHORTCUTS HERE 2")
    }

    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        dismiss(animated: true, completion: nil)
    }
}
