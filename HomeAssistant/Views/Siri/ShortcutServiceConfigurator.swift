//
//  ShortcutServiceConfigurator.swift
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
import ViewRow

@available(iOS 13.0, *)
// swiftlint:disable:next type_body_length
class ShortcutServiceConfigurator: FormViewController {

    var domain: String = "homeassistant"
    var serviceName: String = "check_config"
    var serviceData: ServiceDefinition?
    var entityIDs: [String] = []

    var serviceDataJSON: String?

    // swiftlint:disable cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let infoBarButtonItem = Constants.helpBarButtonItem

        infoBarButtonItem.action = #selector(getInfoAction)
        infoBarButtonItem.target = self

        // Use it as required
        self.navigationItem.rightBarButtonItem = infoBarButtonItem

        self.title = domain + "." + serviceName

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
            <<< TextRow("shortcutName") {
                $0.title = L10n.SiriShortcuts.Configurator.Settings.Name.title
                $0.add(rule: RuleRequired())
            }
            /*<<< SwitchRow("notifyOnRun") {
                $0.title = L10n.SiriShortcuts.Configurator.Settings.NotifyOnRun.title
            }*/

        var setFirstHeaderToFields = false

        if let service = serviceData {
            for (key, field) in service.Fields {
                var footer = ""
                // Need a better way to determine if a field is actually optional than
                // checking description for "optional"
                var optionalField = true
                if let desc = field.Description {
                    footer = desc
                    if desc.range(of: "optional", options: .caseInsensitive) != nil {
                        optionalField = true
                    }
                }

                var exampleValue = field.Example ?? "N/A"

                if let example = field.Example as? Bool {
                    exampleValue = example ? L10n.onLabel : L10n.offLabel
                }

                footer += " \(L10n.SiriShortcuts.Configurator.Fields.Section.footer("\(exampleValue)"))"

                let supportsTemplates = (key.range(of: "template", options: .caseInsensitive) != nil ||
                                         footer.range(of: "template", options: .caseInsensitive) != nil)

                var header = ""
                if setFirstHeaderToFields == false {
                    header = L10n.SiriShortcuts.Configurator.Fields.Section.header
                    setFirstHeaderToFields = true
                }

                var rowsToAdd: [BaseRow] = []

                if key == "entity_id" {
                    rowsToAdd.append(PickerInlineRow<String> {
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
                    })
                } else if supportsTemplates {
                    header = key
                    rowsToAdd.append(TextAreaRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        $0.placeholder = field.Example as? String
                        if let defaultValue = field.Default, let defaultValueStr = defaultValue as? String {
                            $0.value = defaultValueStr
                        }

                    })

                    rowsToAdd.append(ButtonRow {
                        $0.tag = key + "_render_template"
                        $0.title = L10n.previewOutput
                    }.onCellSelection({ cell, _ in
                        if let row = self.form.rowBy(tag: key) as? TextAreaRow, let value = row.value {
                            Current.Log.verbose("Render template from \(value)")

                            HomeAssistantAPI.authenticatedAPI()?.RenderTemplate(templateStr: value).done { val in
                                Current.Log.verbose("Rendered value is \(val)")

                                let alert = UIAlertController(title: L10n.previewOutput, message: val,
                                                              preferredStyle: UIAlertController.Style.alert)
                                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                                              handler: nil))
                                self.present(alert, animated: true, completion: nil)

                                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view

                            }.catch { renderErr in
                                Current.Log.error("Error rendering template! \(renderErr)")
                                let alert = UIAlertController(title: L10n.errorLabel,
                                                              message: renderErr.localizedDescription,
                                                              preferredStyle: UIAlertController.Style.alert)
                                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                                              handler: nil))
                                self.present(alert, animated: true, completion: nil)
                                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
                            }
                        }
                    }))
                } else if let example = field.Example as? Bool {
                    rowsToAdd.append(SwitchRow {
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
                    })
                } else if let example = field.Example as? Double {
                    rowsToAdd.append(DecimalRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        $0.placeholder = example.description
                        if let defaultValue = field.Default, let defaultValueDouble = defaultValue as? Double {
                            $0.value = defaultValueDouble
                        }
                    })
                } else if let example = field.Example as? Int {
                    rowsToAdd.append(IntRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        $0.placeholder = example.description
                        if let defaultValue = field.Default, let defaultValueInt = defaultValue as? Int {
                            $0.value = defaultValueInt
                        }
                    })
                } else if let example = field.Example as? String {
                    rowsToAdd.append(TextRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        $0.placeholder = example
                        if let defaultValue = field.Default, let defaultValueStr = defaultValue as? String {
                            $0.value = defaultValueStr
                        }
                    })
                } else {
                    rowsToAdd.append(TextRow {
                        $0.tag = key
                        $0.title = key
                        if !optionalField {
                            $0.add(rule: RuleRequired())
                        }
                        if let defaultValue = field.Default, let defaultValueStr = defaultValue as? String {
                            $0.value = defaultValueStr
                        }
                    })
                }

                if let defaultVal = field.Default {
                    rowsToAdd.append(ButtonRow {
                        $0.tag = key + "fill_with_default"
                        $0.title = L10n.SiriShortcuts.Configurator.Fields.useDefaultValue
                        }.onCellSelection({ _, _ in
                            self.form.setValues([key: defaultVal])
                            self.tableView.reloadData()
                            if let updatedRow = self.form.rowBy(tag: key) {
                                updatedRow.reload()
                                updatedRow.updateCell()
                            }
                        }))
                }

                if let example = field.Example {
                    rowsToAdd.append(ButtonRow {
                        $0.tag = key + "fill_with_example"
                        $0.title = L10n.SiriShortcuts.Configurator.Fields.useSuggestedValue
                    }.onCellSelection({ _, _ in
                        self.form.setValues([key: example])
                        self.tableView.reloadData()
                        if let updatedRow = self.form.rowBy(tag: key) {
                            updatedRow.reload()
                            updatedRow.updateCell()
                        }
                    }))
                }

                var section = Section(header: header, footer: footer) {
                    $0.tag = key
                }

                section += rowsToAdd

                self.form +++ section

            }
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
            var formData = form.values().filter { $0.value != nil }

            formData.removeValue(forKey: "shortcutName")
            // formData.removeValue(forKey: "notifyOnRun")
            formData.removeValue(forKey: "add_to_siri")

            let serviceIntent = CallServiceIntent(domain: domain, service: serviceName, payload: formData)

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

    @objc
    func getInfoAction(_ sender: Any) {
        Current.Log.verbose("getInfoAction hit, open docs page!")
    }
}

@available(iOS 13.0, *)
extension ShortcutServiceConfigurator: INUIAddVoiceShortcutViewControllerDelegate {

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
@available(iOS 13.0, *)
extension ShortcutServiceConfigurator: INUIEditVoiceShortcutViewControllerDelegate {

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
// swiftlint:disable:next file_length
}
