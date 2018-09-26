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
import FontAwesomeKit
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

        self.title = self.family.name

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

        let allIcons = getIcons()

        self.form
            +++ Section {
                $0.header = HeaderFooterView.init(stringLiteral: "Icon")
                $0.footer = HeaderFooterView.init(stringLiteral: "The image to display.")
                $0.tag = "icon"
                $0.hidden = true
            }

            <<< PushRow<String> {
                    $0.options = Array(allIcons.keys).sorted()
                    $0.value = $0.options?.first
                    $0.selectorTitle = "Choose a icon"
                    $0.tag = "icon"
                }.cellUpdate({ (cell, row) in
                    if let value = row.value {
                        if let theIcon = allIcons[value],
                            let iconColorRow = self.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                            theIcon.addAttribute(NSAttributedString.Key.foregroundColor.rawValue, value: iconColorRow.value)
                            cell.imageView?.image = theIcon.image(with: CGSize(width: CGFloat(30), height: CGFloat(30)))
                        }
                    }
                }).onPresent { from, to in
                    to.selectableRowCellSetup = {cell, row in
                        if let value = row.selectableValue {
                            if let theIcon = allIcons[value],
                                let iconColorRow = self.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                                theIcon.addAttribute(NSAttributedString.Key.foregroundColor.rawValue, value: iconColorRow.value)
                                cell.imageView?.image = theIcon.image(with: CGSize(width: CGFloat(30), height: CGFloat(30)))
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
                            if let theIcon = allIcons[value] {
                                theIcon.addAttribute(NSAttributedString.Key.foregroundColor.rawValue,
                                                     value: picker.value)
                                iconRow.cell.imageView?.image = theIcon.image(with: CGSize(width: CGFloat(30),
                                                                                           height: CGFloat(30)))
                            }
                        }
                    }
                }

        reloadForm(template: self.family.templates.first!)

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

    func renderTemplateForRow(row: String) {
        if let row = self.form.rowBy(tag: row) as? TextAreaRow, let value = row.value {
            print("Render template from", value)

            HomeAssistantAPI.authenticatedAPI()?.RenderTemplate(templateStr: value).done { val in
                print("Rendered value is", val)

                let alert = UIAlertController(title: "Success", message: val,
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

    func getIcons() -> [String:FAKMaterialDesignIcons] {
        // swiftlint:disable:next force_cast
        let allIconsDict = FontAwesomeKit.FAKMaterialDesignIcons.allIcons() as! [String: String]
        var allIcons: [String: FAKMaterialDesignIcons] = [:]

        for (name, iconCode) in allIconsDict {
            let cleanName = name.replacingOccurrences(of: "mdi-", with: "")
            let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(30))

//            theIcon?.addAttribute(NSAttributedString.Key.foregroundColor.rawValue, value: color)
            if let icon = theIcon {
                allIcons[cleanName] = icon
            }
        }

        return allIcons
    }

    func addComplicationTextAreaFormSection(location: ComplicationTextAreas) -> Section {
        let section = Section(header: location.rawValue, footer: location.description) {
            $0.tag = location.rawValue
            $0.hidden = true
        }

        section.append(TextAreaRow {
            $0.tag = location.rawValue
            $0.title = location.rawValue
            $0.add(rule: RuleRequired())
            $0.placeholder = "{{ states(\"weather.current_temperature\") }}"
        })

        section.append(ButtonRow {
            $0.tag = location.rawValue+"_render_template"
            $0.title = "Preview Output"
        }.onCellSelection({ _, _ in
            self.renderTemplateForRow(row: "line"+location.rawValue)
        }))

        section.append(InlineColorPickerRow { (row) in
            row.tag = location.rawValue+"_color"
            row.title = "Color"
            row.isCircular = true
            row.showsPaletteNames = true
            row.value = UIColor.green
            }.onChange { (picker) in
                print("color for "+location.rawValue+": \(picker.value!.hexString(false))")
        })
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
