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

// swiftlint:disable:next type_body_length
class WatchComplicationConfigurator: FormViewController {

    var config: WatchComplication = WatchComplication()
    var newConfig: Bool = true

    convenience init(_ config: WatchComplication?) {
        self.init()

        if let config = config {
            self.config = config
            self.newConfig = false
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
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

        self.title = self.config.Family.name

        let textSections = ComplicationTextAreas.allCases.map({ addComplicationTextAreaFormSection(location: $0) })

        TextAreaRow.defaultCellSetup = { cell, row in
            if #available(iOS 11.0, *) {
                cell.textView.smartQuotesType = .no
                cell.textView.smartDashesType = .no
            }
        }

        let realm = Current.realm()

        self.form

        +++ Section {
            $0.tag = "template"
        }

        <<< PushRow<ComplicationTemplate> {
            $0.tag = "template"
            $0.title = "Template"
            $0.options = self.config.Family.templates
            $0.value = self.config.Template
            $0.selectorTitle = "Choose a template"
        }.onPresent { _, to in
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
                // swiftlint:disable:next force_try
                try! realm.write {
                    self.config.Template = template
                }
                self.reloadForm(template: template)
            }
        }.cellUpdate { cell, row in
            cell.detailTextLabel?.text = row.value?.style
        }.cellSetup { cell, row in
            cell.detailTextLabel?.text = row.value?.style
        }

        self.form.append(contentsOf: textSections)

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
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = value
            }
        }

        <<< ButtonRow {
            $0.tag = "gauge_render_template"
            $0.title = "Preview Output"
            }.onCellSelection({ _, _ in
                self.renderTemplateForRow(rowTag: "gauge")
            })

        <<< InlineColorPickerRow("gauge_color") {
            $0.title = "Color"
            $0.isCircular = true
            $0.showsPaletteNames = true
            $0.value = UIColor.green
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = UIColor(hex: value)
            }
            }.onChange { (picker) in
                print("gauge color: \(picker.value!.hexString(false))")
        }

        <<< SegmentedRow<String> {
            $0.tag = "gauge_type"
            $0.title = "Type"
            $0.add(rule: RuleRequired())
            $0.options = ["open", "closed"]
            $0.value = $0.options?.first
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = value
            }
        }

        <<< SegmentedRow<String> {
            $0.tag = "gauge_style"
            $0.title = "Style"
            $0.add(rule: RuleRequired())
            $0.options = ["fill", "ring"]
            $0.value = $0.options?.first
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = value
            }
        }

        +++ Section(header: "Ring", footer: "The ring showing progress surrounding the text.") {
            $0.tag = "ring"
            $0.hidden = true
        }

        <<< TextAreaRow {
            $0.tag = "ring_value"
            $0.title = "Fractional value"
            $0.add(rule: RuleRequired())
            if let dict = self.config.Data["ring"] as? [String: Any],
                let value = dict[$0.tag!] as? String {
                $0.value = value
            }
        }

        <<< ButtonRow {
            $0.tag = "ring_render_template"
            $0.title = "Preview Output"
        }.onCellSelection({ _, _ in
            self.renderTemplateForRow(rowTag: "ring_value")
        })

        <<< SegmentedRow<String> {
            $0.tag = "ring_type"
            $0.title = "Type"
            $0.add(rule: RuleRequired())
            $0.options = ["open", "closed"]
            $0.value = $0.options?.first
            if let dict = self.config.Data["ring"] as? [String: Any],
                let value = dict[$0.tag!] as? String {
                $0.value = value
            }
        }

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
                if let dict = self.config.Data["icon"] as? [String: Any],
                    let value = dict[$0.tag!] as? String {
                    $0.value = value
                }
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
                if let dict = self.config.Data["icon"] as? [String: Any],
                    let value = dict[$0.tag!] as? String {
                    $0.value = UIColor(hex: value)
                }
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

        reloadForm(template: self.config.Family.templates.first!)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidDisappear(_ animated: Bool) {
        if self.isBeingDismissed || self.isMovingFromParent {
            let realm = Current.realm()

            // swiftlint:disable:next force_try
            try! realm.write {
                self.config.Data = getValuesGroupedBySection()

                print("COMPLICATION", self.config, self.config.Data)

                realm.add(self.config, update: true)
            }
        }
    }

    @objc
    func getInfoAction(_ sender: Any) {
        // FIXME: Actually open a modal window with docs!
        print("getInfoAction hit, open docs page!")
    }

    func renderTemplateForRow(rowTag: String) {
        if let row = self.form.rowBy(tag: rowTag) as? TextAreaRow, let value = row.value {
            print("Render template from", value)

            renderTemplateValue(value)
        }
    }

    func renderTemplateForRow(row: BaseRow) {
        if let value = row.baseValue as? String {
            print("Render template from", value)

            renderTemplateValue(value)
        }
    }

    func renderTemplateValue(_ value: String) {
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

    func addComplicationTextAreaFormSection(location: ComplicationTextAreas) -> Section {
        let key = "textarea_" + location.slug
        let section = Section(header: location.label, footer: location.description) {
            $0.tag = location.slug
            $0.hidden = true
        }

        var dataDict: [String: Any] = [String: Any]()

        if let textAreasDict = self.config.Data["textAreas"] as? [String: [String: Any]],
            let slugDict = textAreasDict[location.slug] {
            dataDict = slugDict
        }

        let textRow = TextAreaRow {
            $0.tag = key + "_text"
            $0.title = location.label
            $0.add(rule: RuleRequired())
            $0.placeholder = "{{ states(\"weather.current_temperature\") }}"
            if let value = dataDict["text"] as? String {
                $0.value = value
            }
        }

        section.append(textRow)

        section.append(ButtonRow {
            $0.title = "Preview Output"
        }.onCellSelection({ _, _ in
            self.renderTemplateForRow(row: textRow)
        }))

        section.append(InlineColorPickerRow {
            $0.tag = key + "_color"
            $0.title = "Color"
            $0.isCircular = true
            $0.showsPaletteNames = true
            $0.value = UIColor.green
            if let value = dataDict["color"] as? String {
                $0.value = UIColor(hex: value)
            }
        }.onChange { (picker) in
            print("color for "+location.rawValue+": \(picker.value!.hexString(false))")
        })

        return section
    }

    // swiftlint:disable:next cyclomatic_complexity
    func reloadForm(template: ComplicationTemplate) {
        for section in self.form.allSections {
            if section.tag == "template" {
                continue
            }
            section.hidden = true
            section.evaluateHidden()
        }

        for textarea in template.textAreas {
            if let section = self.form.sectionBy(tag: textarea.slug) {
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

        if template.hasRing, let ringSection = self.form.sectionBy(tag: "ring") {
            ringSection.hidden = false
            ringSection.evaluateHidden()
        }

        if template.supportsRow2Alignment, let row2AlignmentSection = self.form.sectionBy(tag: "row2alignment") {
            row2AlignmentSection.hidden = false
            row2AlignmentSection.evaluateHidden()
        }
    }

    func getValuesGroupedBySection() -> [String: Any] {
        var groupedVals: [String: [String: Any]] = [:]
        var textAreasDict: [String: [String: Any]] = [:]

        for row in self.form.allRows {
            if row.section!.isHidden || row.section!.tag == "template" {
                continue
            }

            if let section = row.section, let sectionTag = section.tag, var rowTag = row.tag,
                var rowValue = row.baseValue {

                if rowTag.contains("color"), let color = rowValue as? UIColor {
                    rowValue = color.hexString(true)
                }

                let rowTagPrefix = "textarea_" + sectionTag + "_"
                if rowTag.hasPrefix(rowTagPrefix) {
                    rowTag = rowTag.replacingOccurrences(of: rowTagPrefix, with: "")

                    if textAreasDict[sectionTag] == nil {
                        textAreasDict[sectionTag] = [String: Any]()
                    }

                    textAreasDict[sectionTag]![rowTag] = rowValue

                    if rowTag == "text", let value = rowValue as? String {
                        textAreasDict[sectionTag]!["textNeedsRender"] = (value.contains("{{") || value.contains("}}"))
                    }

                } else {
                    if groupedVals[sectionTag] == nil {
                        groupedVals[sectionTag] = [String: Any]()
                    }

                    groupedVals[sectionTag]![rowTag] = rowValue
                }
            }
        }

        groupedVals["textAreas"] = textAreasDict

        print("groupedVals", groupedVals)

        return groupedVals
    }
// swiftlint:disable:next file_length
}
