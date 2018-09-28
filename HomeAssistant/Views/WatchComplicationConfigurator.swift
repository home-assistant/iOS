//
//  WatchComplicationConfigurator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/25/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import Shared
import PromiseKit
import ObjectMapper
import ColorPickerRow
import Iconic
import WatchKit
import WatchConnectivity

class WatchComplicationConfigurator: FormViewController {

    var family: ComplicationGroupMember = .modularSmall
    var chosenTemplate: ComplicationTemplate?

    // swiftlint:disable:next function_body_length
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

        let allComplications = Current.realm().objects(WatchComplication.self)

        print("All configured complications", allComplications, allComplications.count, allComplications.first)

        self.title = self.family.name

        TextAreaRow.defaultCellSetup = { cell, row in
            if #available(iOS 11.0, *) {
                cell.textView.smartQuotesType = .no
                cell.textView.smartDashesType = .no
            }
        }

        self.form
            +++ Section {
                $0.tag = "template"
            }

        <<< PushRow<ComplicationTemplate> {
            $0.tag = "template"
            $0.title = "Template"
            $0.options = self.family.templates
            $0.value = $0.options?.first
            $0.selectorTitle = "Choose a template"
        }.onPresent { from, to in
            to.enableDeselection = false
            to.selectableRowSetup = { row in
                row.cellStyle = .subtitle
            }
            to.selectableRowCellSetup = { cell, row in
                cell.textLabel?.text = row.selectableValue?.style
                cell.detailTextLabel?.text = row.selectableValue?.description
                cell.detailTextLabel?.numberOfLines = 0
                cell.detailTextLabel?.lineBreakMode = .byWordWrapping
            }
            to.selectableRowCellUpdate = { cell, row in
                cell.textLabel?.text = row.selectableValue?.style
                cell.detailTextLabel?.text = row.selectableValue?.description
            }
        }.onChange { row in
            if let template = row.value {
                self.chosenTemplate = template
                self.reloadForm(template: template)
            }
        }.cellUpdate { cell, row in
            cell.detailTextLabel?.text = row.value?.style
        }.cellSetup { cell, row in
            cell.detailTextLabel?.text = row.value?.style
        }

        for textArea in ComplicationTextAreas.allCases {
            self.form
                +++ addComplicationTextAreaFormSection(location: textArea)
        }

        self.form
            +++ Section {
                $0.tag = "row2alignment"
                $0.hidden = true
            }

            <<< SegmentedRow<String> {
                $0.tag = "row2alignment"
                $0.title = "Row 2 Alignment"
                $0.add(rule: RuleRequired())
                $0.options = ["leading", "trailing"]
                $0.value = $0.options?.first
            }

            +++ Section(header: "Gauge",
                        footer: "The gague to display in the complication.") {
                            $0.tag = "gauge"
                            $0.hidden = true
            }

            <<< TextAreaRow {
                $0.tag = "gauge"
                $0.title = "Gauge"
                $0.add(rule: RuleRequired())
            }

            <<< ButtonRow {
                $0.tag = "gauge_render_template"
                $0.title = "Preview Output"
                }.onCellSelection({ _, _ in
                    self.renderTemplateForRow(row: "gauge")
                })

            <<< InlineColorPickerRow("gauge_color") { (row) in
                row.title = "Color"
                row.isCircular = true
                row.showsPaletteNames = true
                row.value = UIColor.green
                }.onChange { (picker) in
                    print("gauge color: \(picker.value!.hexString(false))")
            }

            <<< SegmentedRow<String> {
                $0.tag = "gauge_type"
                $0.title = "Type"
                $0.add(rule: RuleRequired())
                $0.options = ["open", "closed"]
                $0.value = $0.options?.first
            }

            <<< SegmentedRow<String> {
                $0.tag = "gauge_style"
                $0.title = "Style"
                $0.add(rule: RuleRequired())
                $0.options = ["fill", "ring"]
                $0.value = $0.options?.first
        }

        self.form
            +++ Section {
                $0.header = HeaderFooterView.init(stringLiteral: "Icon")
                $0.footer = HeaderFooterView.init(stringLiteral: "The image to display.")
                $0.tag = "icon"
                $0.hidden = true
            }

            <<< PushRow<String> {
                    $0.options = MaterialDesignIcons.allCases.map({ $0.name })
                    $0.value = $0.options?.first
                    $0.selectorTitle = "Choose a icon"
                    $0.tag = "icon"
                }.cellUpdate({ (cell, row) in
                    if let value = row.value {
                        let theIcon = MaterialDesignIcons(named: value)
                        if let iconColorRow = self.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                            cell.imageView?.image = theIcon.image(ofSize: CGSize(width: CGFloat(30),
                                                                                 height: CGFloat(30)),
                                                                  color: iconColorRow.value)
                        }
                    }
                }).onPresent { from, to in
                    to.selectableRowCellSetup = {cell, row in
                        if let value = row.selectableValue {
                            let theIcon = MaterialDesignIcons(named: value)
                            if let iconColorRow = self.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                                cell.imageView?.image = theIcon.image(ofSize: CGSize(width: CGFloat(30),
                                                                                     height: CGFloat(30)),
                                                                      color: iconColorRow.value)
                            }
                        }
                    }
                    to.selectableRowCellUpdate = { cell, row in
                        cell.textLabel?.text = row.selectableValue!
                    }
                }

            <<< InlineColorPickerRow("icon_color") {
                    $0.title = "Color"
                    $0.isCircular = true
                    $0.showsPaletteNames = true
                    $0.value = UIColor.green
                }.onChange { (picker) in
                    print("icon color: \(picker.value!.hexString(false))")
                    if let iconRow = self.form.rowBy(tag: "icon") as? PushRow<String> {
                        if let value = iconRow.value {
                            let theIcon = MaterialDesignIcons(named: value)
                            iconRow.cell.imageView?.image = theIcon.image(ofSize: CGSize(width: CGFloat(30),
                                                                                         height: CGFloat(30)),
                                                                          color: picker.value)
                        }
                    }
                }

        reloadForm(template: self.family.templates.first!)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidDisappear(_ animated: Bool) {
        if self.isBeingDismissed || self.isMovingFromParent {
            var templateName = "UNKNOWN"

            if let template = self.form.rowBy(tag: "template") as? PushRow<ComplicationTemplate>,
                let value = template.value {
                templateName = value.rawValue
            }

            var formVals = self.form.values(includeHidden: false)

            for (key, val) in formVals {
                if key.contains("color"), let color = val as? UIColor {
                    formVals[key] = color.hexString(true)
                }
            }

            formVals.removeValue(forKey: "template")

            print("BYE BYE CONFIGURATOR", formVals)

            let complication = WatchComplication()
            complication.Family = self.family.rawValue
            complication.Template = templateName
            complication.Data = formVals as [String: Any]
            print("COMPLICATION", complication)

            let realm = Current.realm()

            print("Realm is located at:", realm.configuration.fileURL!)

            // swiftlint:disable:next force_try
            try! realm.write {
                realm.add(complication, update: true)
            }
        }
    }

    @objc
    func getInfoAction(_ sender: Any) {
        // FIXME: Actually open a modal window with docs!
        print("getInfoAction hit, open docs page!")
    }

    func renderTemplateForRow(row: String) {
        if let row = self.form.rowBy(tag: row) as? TextAreaRow, let value = row.value {
            print("Render template from", value)

            HomeAssistantAPI.authenticatedAPI()?.RenderTemplate(templateStr: value).done { val in
                print("Rendered value is", val)

                let alert = UIAlertController(title: "Output Preview", message: val,
                                              preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                              handler: nil))
                self.present(alert, animated: true, completion: nil)

                }.catch { renderErr in
                    print("Error rendering template!", renderErr.localizedDescription)
                    let alert = UIAlertController(title: L10n.errorLabel,
                                                  message: renderErr.localizedDescription,
                                                  preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                                  handler: nil))
                    self.present(alert, animated: true, completion: nil)
            }
        }
    }

    func addComplicationTextAreaFormSection(location: ComplicationTextAreas) -> Section {
        var cleanLocation = location.rawValue.lowercased()
        cleanLocation = cleanLocation.replacingOccurrences(of: " ", with: "")
        cleanLocation = cleanLocation.replacingOccurrences(of: ",", with: "")
        let key = cleanLocation + "_text"
        let section = Section(header: location.label, footer: location.description) {
            $0.tag = location.rawValue
            $0.hidden = true
        }

        <<< TextAreaRow {
            $0.tag = key
            $0.title = location.label
            $0.add(rule: RuleRequired())
            $0.placeholder = "{{ states(\"weather.current_temperature\") }}"
        }

        <<< ButtonRow {
            $0.title = "Preview Output"
        }.onCellSelection({ _, _ in
            self.renderTemplateForRow(row: key)
        })

        <<< InlineColorPickerRow { (row) in
            row.tag = key+"_color"
            row.title = "Color"
            row.isCircular = true
            row.showsPaletteNames = true
            row.value = UIColor.green
        }.onChange { (picker) in
            print("color for "+key+": \(picker.value!.hexString(false))")
        }

        return section
    }

    func reloadForm(template: ComplicationTemplate) {
        for section in self.form.allSections {
            if section.tag == "template" {
                continue
            }
            section.hidden = true
            section.evaluateHidden()
        }

        for textarea in template.textAreas {
            if let section = self.form.sectionBy(tag: textarea.rawValue) {
                section.hidden = false
                section.evaluateHidden()
            }
        }

        if template.hasGauge, let gaugeSection = self.form.sectionBy(tag: "gauge") {
            gaugeSection.hidden = false
            gaugeSection.evaluateHidden()
            if let gaugeType = self.form.rowBy(tag: "gauge_type") as? SegmentedRow<String> {
                if template.gaugeIsOpenStyle {
                    gaugeType.value = gaugeType.options?[0]
                } else if template.gaugeIsClosedStyle {
                    gaugeType.value = gaugeType.options?[1]
                }
                gaugeType.disabled = true
                gaugeType.evaluateDisabled()
                gaugeType.reload()
            }
        }

        if template.hasImage, let iconSection = self.form.sectionBy(tag: "icon") {
            iconSection.hidden = false
            iconSection.evaluateHidden()
        }

        if template.supportsRow2Alignment, let row2AlignmentSection = self.form.sectionBy(tag: "row2alignment") {
            row2AlignmentSection.hidden = false
            row2AlignmentSection.evaluateHidden()
        }
    }
}
