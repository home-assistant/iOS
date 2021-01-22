//
//  ComplicationEditViewController.swift
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

// swiftlint:disable:next type_body_length
class ComplicationEditViewController: FormViewController, TypedRowControllerType {

    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    let config: WatchComplication
    private var displayTemplate: ComplicationTemplate

    init(config: WatchComplication) {
        self.config = config
        self.displayTemplate = config.Template

        super.init(style: .grouped)

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc private func save() {
        do {
            let realm = Current.realm()
            try realm.write {
                if let name = (form.rowBy(tag: "name") as? TextRow)?.value, name.isEmpty == false {
                    config.name = name
                } else {
                    config.name = nil
                }
                if let IsPublic = (form.rowBy(tag: "IsPublic") as? SwitchRow)?.value {
                    config.IsPublic = IsPublic
                } else {
                    config.IsPublic = true
                }
                config.Template = displayTemplate
                config.Data = getValuesGroupedBySection()

                Current.Log.verbose("COMPLICATION \(config) \(config.Data)")

                realm.add(config, update: .all)
            }
        } catch {
            Current.Log.error(error)
        }

        Current.api.then { api in
            api.updateComplications(passively: false)
        }.cauterize()

        onDismissCallback?(self)
    }

    @objc private func deleteComplication(_ sender: UIView) {
        precondition(config.realm != nil)

        let alert = UIAlertController(
            title: L10n.Watch.Configurator.Delete.title,
            message: L10n.Watch.Configurator.Delete.message,
            preferredStyle: .actionSheet
        )
        with(alert.popoverPresentationController) {
            $0?.sourceView = sender
            $0?.sourceRect = sender.bounds
        }
        alert.addAction(UIAlertAction(
                            title: L10n.Watch.Configurator.Delete.button, style: .destructive, handler: { [config] _ in
            let realm = Current.realm()
            do {
                try realm.write {
                    realm.delete(config)
                }
            } catch {
                Current.Log.error(error)
            }

            Current.api.then { api in
                api.updateComplications(passively: false)
            }.cauterize()

            self.onDismissCallback?(self)
        }))
        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancel)
            )
        ]

        let infoBarButtonItem = Constants.helpBarButtonItem

        infoBarButtonItem.action = #selector(getInfoAction)
        infoBarButtonItem.target = self

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .save,
                target: self,
                action: #selector(save)
            ),
            infoBarButtonItem
        ]

        self.title = self.config.Family.name

        let textSections = ComplicationTextAreas.allCases.map({ addComplicationTextAreaFormSection(location: $0) })

        TextAreaRow.defaultCellSetup = { cell, _ in
            cell.textView.smartQuotesType = .no
            cell.textView.smartDashesType = .no
        }

        self.form

        +++ Section {
            $0.tag = "template"
        }

        <<< TextRow("name") {
            $0.title = L10n.Watch.Configurator.Rows.DisplayName.title
            $0.placeholder = self.config.Family.name
            $0.value = self.config.name
        }

        <<< PushRow<ComplicationTemplate> {
            $0.tag = "template"
            $0.title = L10n.Watch.Configurator.Rows.Template.title
            $0.options = self.config.Family.templates
            $0.value = displayTemplate
            $0.selectorTitle = L10n.Watch.Configurator.Rows.Template.selectorTitle
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
                if #available(iOS 13, *) {
                    cell.detailTextLabel?.textColor = .secondaryLabel
                } else {
                    cell.detailTextLabel?.textColor = .darkGray
                }
            }
            to.selectableRowCellUpdate = { cell, row in
                cell.textLabel?.text = row.selectableValue?.style
                cell.detailTextLabel?.text = row.selectableValue?.description
            }
        }.onChange { [weak self] row in
            if let template = row.value {
                self?.displayTemplate = template
                self?.reloadForm()
            }
        }.cellUpdate { cell, row in
            cell.detailTextLabel?.text = row.value?.style
        }.cellSetup { cell, row in
            cell.detailTextLabel?.text = row.value?.style
        }

        <<< SwitchRow("IsPublic") {
            $0.title = L10n.Watch.Configurator.Rows.IsPublic.title
            $0.value = self.config.IsPublic
        }

        self.form.append(contentsOf: textSections)

        self.form

        +++ Section {
            $0.tag = "column2alignment"
            $0.hidden = .function([], { [weak self] _ in
                return self?.displayTemplate.supportsColumn2Alignment == false
            })
        }

        <<< SegmentedRow<String> {
            $0.tag = "column2alignment"
            $0.title = L10n.Watch.Configurator.Rows.Column2Alignment.title
            $0.add(rule: RuleRequired())
            $0.options = ["leading", "trailing"]
            $0.displayValueFor = {
                if $0?.lowercased() == "leading" {
                    return L10n.Watch.Configurator.Rows.Column2Alignment.Options.leading
                } else {
                    return L10n.Watch.Configurator.Rows.Column2Alignment.Options.trailing
                }
            }
            $0.value = $0.options?.first
            if let info = self.config.Data["column2alignment"] as? [String: Any],
                let value = info[$0.tag!] as? String {
                $0.value = value
            }
        }

        +++ Section(header: L10n.Watch.Configurator.Sections.Gauge.header,
                    footer: L10n.Watch.Configurator.Sections.Gauge.footer) {
            $0.tag = "gauge"
            $0.hidden = .function([], { [weak self] _ in
                return self?.displayTemplate.hasGauge == false
            })
        }

        <<< TextAreaRow {
            $0.tag = "gauge"
            $0.title = L10n.Watch.Configurator.Rows.Gauge.title
            $0.placeholder = "{{ range(1, 100) | random / 100.0 }}"
            $0.add(rule: RuleRequired())
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = value
            }
        }

        <<< ButtonRow {
            $0.tag = "gauge_render_template"
            $0.title = L10n.previewOutput
            }.onCellSelection({ _, _ in
                self.renderTemplateForRow(rowTag: "gauge", expectingPercentile: true)
            })

        <<< InlineColorPickerRow("gauge_color") {
            $0.title = L10n.Watch.Configurator.Rows.Gauge.Color.title
            $0.isCircular = true
            $0.showsPaletteNames = true
            $0.value = UIColor.green
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = UIColor(hex: value)
            }
            }.onChange { (picker) in
                Current.Log.verbose("gauge color: \(picker.value!.hexString(false))")
        }

        <<< SegmentedRow<String> {
            $0.tag = "gauge_type"
            $0.title = L10n.Watch.Configurator.Rows.Gauge.GaugeType.title
            $0.add(rule: RuleRequired())
            $0.options = ["open", "closed"]
            $0.displayValueFor = {
                if $0?.lowercased() == "open" {
                    return L10n.Watch.Configurator.Rows.Gauge.GaugeType.Options.open
                } else {
                    return L10n.Watch.Configurator.Rows.Gauge.GaugeType.Options.closed
                }
            }
            $0.value = $0.options?.first
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = value
            }
        }

        <<< SegmentedRow<String> {
            $0.tag = "gauge_style"
            $0.title = L10n.Watch.Configurator.Rows.Gauge.Style.title
            $0.add(rule: RuleRequired())
            $0.options = ["fill", "ring"]
            $0.displayValueFor = {
                if $0?.lowercased() == "fill" {
                    return L10n.Watch.Configurator.Rows.Gauge.Style.Options.fill
                } else {
                    return L10n.Watch.Configurator.Rows.Gauge.Style.Options.ring
                }
            }
            $0.value = $0.options?.first
            if let gaugeDict = self.config.Data["gauge"] as? [String: Any],
                let value = gaugeDict[$0.tag!] as? String {
                $0.value = value
            }
        }

        +++ Section(header: L10n.Watch.Configurator.Sections.Ring.header,
                    footer: L10n.Watch.Configurator.Sections.Ring.footer) {
            $0.tag = "ring"
            $0.hidden = .function([], { [weak self] _ in
                return self?.displayTemplate.hasRing == false
            })
        }

        <<< TextAreaRow {
            $0.tag = "ring_value"
            $0.title = L10n.Watch.Configurator.Rows.Ring.Value.title
            $0.placeholder = "{{ range(1, 100) | random / 100.0 }}"
            $0.add(rule: RuleRequired())
            if let dict = self.config.Data["ring"] as? [String: Any],
                let value = dict[$0.tag!] as? String {
                $0.value = value
            }
        }

        <<< ButtonRow {
            $0.tag = "ring_render_template"
            $0.title = L10n.previewOutput
        }.onCellSelection({ _, _ in
            self.renderTemplateForRow(rowTag: "ring_value", expectingPercentile: true)
        })

        <<< SegmentedRow<String> {
            $0.tag = "ring_type"
            $0.title = L10n.Watch.Configurator.Rows.Ring.RingType.title
            $0.add(rule: RuleRequired())
            $0.options = ["open", "closed"]

            $0.displayValueFor = { value in
                if value?.lowercased() == "open" {
                    return L10n.Watch.Configurator.Rows.Ring.RingType.Options.open
                } else {
                    return L10n.Watch.Configurator.Rows.Ring.RingType.Options.closed
                }
            }

            $0.value = $0.options?.first
            if let dict = self.config.Data["ring"] as? [String: Any],
                let value = dict[$0.tag!] as? String {
                $0.value = value
            }
        }

        <<< InlineColorPickerRow("ring_color") {
                $0.title = L10n.Watch.Configurator.Rows.Ring.Color.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor.green
                if let dict = self.config.Data["ring"] as? [String: Any],
                    let value = dict[$0.tag!] as? String {
                    $0.value = UIColor(hex: value)
                }
            }.onChange { (picker) in
                Current.Log.verbose("ring color: \(picker.value!.hexString(false))")
            }

        +++ Section(header: L10n.Watch.Configurator.Sections.Icon.header,
                    footer: L10n.Watch.Configurator.Sections.Icon.footer) {
            $0.tag = "icon"
            $0.hidden = .function([], { [weak self] _ in
                return self?.displayTemplate.hasImage == false
            })
        }

        <<< SearchPushRow<MaterialDesignIcons> {
                $0.options = MaterialDesignIcons.allCases
                $0.value = $0.options?.first
                $0.displayValueFor = { icon in
                    icon?.name
                }
                $0.selectorTitle = L10n.Watch.Configurator.Rows.Icon.Choose.title
                $0.tag = "icon"
                if let dict = self.config.Data["icon"] as? [String: Any],
                    let value = dict[$0.tag!] as? String {
                    $0.value = MaterialDesignIcons(named: value)
                }
            }.cellUpdate({ (cell, row) in
                if let value = row.value {
                    if let iconColorRow = self.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                        cell.imageView?.image = value.image(ofSize: CGSize(width: CGFloat(30),
                                                                           height: CGFloat(30)),
                                                            color: iconColorRow.value)
                    }
                }
            }).onPresent { _, to in
                to.selectableRowCellUpdate = { cell, row in
                    if let value = row.selectableValue {
                        if let iconColorRow = self.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                            cell.imageView?.image = value.image(ofSize: CGSize(width: CGFloat(30),
                                                                               height: CGFloat(30)),
                                                                color: iconColorRow.value)
                        }

                        cell.textLabel?.text = value.name
                    }
                }
            }

        <<< InlineColorPickerRow("icon_color") {
                $0.title = L10n.Watch.Configurator.Rows.Icon.Color.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor.green
                if let dict = self.config.Data["icon"] as? [String: Any],
                    let value = dict[$0.tag!] as? String {
                    $0.value = UIColor(hex: value)
                }
            }.onChange { (picker) in
                Current.Log.verbose("icon color: \(picker.value!.hexString(false))")
                if let iconRow = self.form.rowBy(tag: "icon") as? SearchPushRow<MaterialDesignIcons> {
                    if let value = iconRow.value {
                        iconRow.cell.imageView?.image = value.image(ofSize: CGSize(width: CGFloat(30),
                                                                                   height: CGFloat(30)),
                                                                    color: picker.value)
                    }
                }
            }

        +++ Section { [config] section in
            section.tag = "delete"

            if config.realm == nil {
                // don't need to show a delete button for an unpersisted complication
                section.hidden = true
            }
        }
        <<< ButtonRow {
            $0.title = L10n.Watch.Configurator.Delete.button
            $0.onCellSelection { [weak self] cell, _ in
                self?.deleteComplication(cell)
            }
            $0.cellUpdate { cell, _ in
                if #available(iOS 13, *) {
                    cell.textLabel?.textColor = .systemRed
                } else {
                    cell.textLabel?.textColor = .red
                }
            }
        }

        reloadForm()
    }

    @objc
    func getInfoAction(_ sender: Any) {
        openURLInBrowser(URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!, self)
    }

    func renderTemplateForRow(rowTag: String, expectingPercentile: Bool) {
        if let row = self.form.rowBy(tag: rowTag) as? TextAreaRow, let value = row.value {
            Current.Log.verbose("Render template from \(value)")

            renderTemplateValue(value, row, expectingPercentile: expectingPercentile)
        }
    }

    func renderTemplateForRow(row: BaseRow, expectingPercentile: Bool) {
        if let value = row.baseValue as? String {
            Current.Log.verbose("Render template from \(value)")

            renderTemplateValue(value, row, expectingPercentile: expectingPercentile)
        }
    }

    enum RenderValueError: LocalizedError {
        case expectedFloat(value: Any)
        case outOfRange(value: Float)

        var errorDescription: String? {
            switch self {
            case .expectedFloat(value: let value):
                return L10n.Watch.Configurator.PreviewError.notNumber(type(of: value), value)
            case .outOfRange(value: let value):
                return L10n.Watch.Configurator.PreviewError.outOfRange(value)
            }
        }
    }

    func renderTemplateValue(_ value: String, _ row: BaseRow, expectingPercentile: Bool) {
        Current.api.then {
            $0.RenderTemplate(templateStr: value)
        }.get { result in
            if expectingPercentile {
                if let number = WatchComplication.percentileNumber(from: result) {
                    if !(0...1 ~= number) {
                        throw RenderValueError.outOfRange(value: number)
                    }
                } else {
                    throw RenderValueError.expectedFloat(value: result)
                }
            }
        }.done { [self] val in
            Current.Log.verbose("Rendered value is \(val)")

            let alert = UIAlertController(
                title: L10n.previewOutput,
                message: String(describing: val),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: L10n.okLabel,
                style: .default,
                handler: nil
            ))
            present(alert, animated: true, completion: nil)
        }.catch { [self] renderErr in
            Current.Log.error("Error rendering template! \(renderErr)")
            let alert = UIAlertController(
                title: L10n.errorLabel,
                message: renderErr.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: L10n.okLabel,
                style: .default,
                handler: nil
            ))
            present(alert, animated: true, completion: nil)
        }
    }

    func addComplicationTextAreaFormSection(location: ComplicationTextAreas) -> Section {
        let key = "textarea_" + location.slug
        let section = Section(header: location.label, footer: location.description) {
            $0.tag = location.slug
            $0.hidden = .function([], { [weak self] _ in
                return self?.displayTemplate.textAreas.map(\.slug).contains(location.slug) == false
            })
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
            $0.title = L10n.previewOutput
        }.onCellSelection({ _, _ in
            self.renderTemplateForRow(row: textRow, expectingPercentile: false)
        }))

        section.append(InlineColorPickerRow {
            $0.tag = key + "_color"
            $0.title = L10n.Watch.Configurator.Rows.Color.title
            $0.isCircular = true
            $0.showsPaletteNames = true
            $0.value = UIColor.green
            if let value = dataDict["color"] as? String {
                $0.value = UIColor(hex: value)
            }
        }.onChange { (picker) in
            Current.Log.verbose("color for "+location.rawValue+": \(picker.value!.hexString(false))")
        })

        return section
    }

    func reloadForm() {
        for section in self.form.allSections {
            section.evaluateHidden()
        }

        if displayTemplate.hasGauge, let gaugeType = self.form.rowBy(tag: "gauge_type") as? SegmentedRow<String> {
            if displayTemplate.gaugeIsOpenStyle {
                gaugeType.value = gaugeType.options?[0]
            } else if displayTemplate.gaugeIsClosedStyle {
                gaugeType.value = gaugeType.options?[1]
            }
            gaugeType.disabled = true
            gaugeType.evaluateDisabled()
            gaugeType.reload()
        }
    }

    func getValuesGroupedBySection() -> [String: Any] {
        var groupedVals: [String: [String: Any]] = [:]
        var textAreasDict: [String: [String: Any]] = [:]

        for row in self.form.allRows {
            if row.section!.isHidden || row.section!.tag == "template" || row.section!.tag == "delete" {
                continue
            }

            if let section = row.section, let sectionTag = section.tag, var rowTag = row.tag,
                var rowValue = row.baseValue {

                if rowTag.contains("color"), let color = rowValue as? UIColor {
                    rowValue = color.hexString(true)
                }

                if let mdi = rowValue as? MaterialDesignIcons {
                    rowValue = mdi.name
                }

                let rowTagPrefix = "textarea_" + sectionTag + "_"
                if rowTag.hasPrefix(rowTagPrefix) {
                    rowTag = rowTag.replacingOccurrences(of: rowTagPrefix, with: "")

                    if textAreasDict[sectionTag] == nil {
                        textAreasDict[sectionTag] = [String: Any]()
                    }

                    textAreasDict[sectionTag]![rowTag] = rowValue
                } else {
                    if groupedVals[sectionTag] == nil {
                        groupedVals[sectionTag] = [String: Any]()
                    }

                    groupedVals[sectionTag]![rowTag] = rowValue
                }
            }
        }

        groupedVals["textAreas"] = textAreasDict

        Current.Log.verbose("groupedVals \(groupedVals)")

        return groupedVals
    }
// swiftlint:disable:next file_length
}
