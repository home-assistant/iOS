import ColorPickerRow
import Eureka
import Foundation
import ObjectMapper
import PromiseKit
import Shared
import UIKit

class ComplicationEditViewController: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    let config: WatchComplication
    private var displayTemplate: ComplicationTemplate
    private var server: Server {
        if let value = (form.rowBy(tag: "server") as? ServerSelectRow)?.value, let server = value.server {
            return server
        } else {
            return Current.servers.all.first!
        }
    }

    init(config: WatchComplication) {
        self.config = config
        self.displayTemplate = config.Template

        super.init()

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc private func save() {
        let realm = Current.realm()
        realm.reentrantWrite {
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
            config.serverIdentifier = server.identifier.rawValue
            config.Template = displayTemplate
            config.Data = getValuesGroupedBySection()

            Current.Log.verbose("COMPLICATION \(config) \(config.Data)")

            realm.add(config, update: .all)
        }.then(on: nil) { [server] in
            Current.api(for: server).updateComplications(passively: false)
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
            title: L10n.Watch.Configurator.Delete.button, style: .destructive, handler: { [config, server] _ in
                let realm = Current.realm()
                realm.reentrantWrite {
                    realm.delete(config)
                }.then(on: nil) {
                    Current.api(for: server).updateComplications(passively: false)
                }.cauterize()

                self.onDismissCallback?(self)
            }
        ))
        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancel)
            ),
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
            infoBarButtonItem,
        ]

        title = config.Family.name

        let textSections = ComplicationTextAreas.allCases.map({ addComplicationTextAreaFormSection(location: $0) })

        form

            +++ Section {
                $0.tag = "template"
            }

            <<< TextRow("name") {
                $0.title = L10n.Watch.Configurator.Rows.DisplayName.title
                $0.placeholder = config.Family.name
                $0.value = config.name
            }

            <<< ServerSelectRow("server") {
                if let server = Current.servers.server(forServerIdentifier: config.serverIdentifier) {
                    $0.value = .server(server)
                } else {
                    $0.value = Current.servers.all.first.flatMap { .server($0) }
                }
                $0.onChange { [form] row in
                    for section in form.allSections {
                        if let section = section as? TemplateSection, let server = row.value?.server {
                            section.server = server
                        }
                    }
                }
            }

            <<< PushRow<ComplicationTemplate> {
                $0.tag = "template"
                $0.title = L10n.Watch.Configurator.Rows.Template.title
                $0.options = config.Family.templates
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
                $0.value = config.IsPublic
            }

        form.append(contentsOf: textSections)

        form

            +++ Section {
                $0.tag = "column2alignment"
                $0.hidden = .function([], { [weak self] _ in
                    self?.displayTemplate.supportsColumn2Alignment == false
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
                if let info = config.Data["column2alignment"] as? [String: Any],
                   let value = info[$0.tag!] as? String {
                    $0.value = value
                }
            }

            +++ TemplateSection(
                header: L10n.Watch.Configurator.Sections.Gauge.header,
                footer: L10n.Watch.Configurator.Sections.Gauge.footer,
                displayResult: { try Self.validate(result: $0, expectingPercentile: true) },
                server: server,
                initializeInput: {
                    $0.tag = "gauge"
                    $0.title = L10n.Watch.Configurator.Rows.Gauge.title
                    $0.placeholder = "{{ range(1, 100) | random / 100.0 }}"
                    $0.add(rule: RuleRequired())
                    if let gaugeDict = config.Data["gauge"] as? [String: Any],
                       let value = gaugeDict[$0.tag!] as? String {
                        $0.value = value
                    }

                }, initializeSection: {
                    $0.tag = "gauge"
                    $0.hidden = .function([], { [weak self] _ in
                        self?.displayTemplate.hasGauge == false
                    })
                }
            )

            <<< InlineColorPickerRow("gauge_color") {
                $0.title = L10n.Watch.Configurator.Rows.Gauge.Color.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor.green
                if let gaugeDict = config.Data["gauge"] as? [String: Any],
                   let value = gaugeDict[$0.tag!] as? String {
                    $0.value = UIColor(hex: value)
                }
            }.onChange { picker in
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
                if let gaugeDict = config.Data["gauge"] as? [String: Any],
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
                if let gaugeDict = config.Data["gauge"] as? [String: Any],
                   let value = gaugeDict[$0.tag!] as? String {
                    $0.value = value
                }
            }

            +++ TemplateSection(
                header: L10n.Watch.Configurator.Sections.Ring.header,
                footer: L10n.Watch.Configurator.Sections.Ring.footer,
                displayResult: { try Self.validate(result: $0, expectingPercentile: true) },
                server: server,
                initializeInput: {
                    $0.tag = "ring_value"
                    $0.title = L10n.Watch.Configurator.Rows.Ring.Value.title
                    $0.placeholder = "{{ range(1, 100) | random / 100.0 }}"
                    $0.add(rule: RuleRequired())
                    if let dict = config.Data["ring"] as? [String: Any],
                       let value = dict[$0.tag!] as? String {
                        $0.value = value
                    }
                }, initializeSection: {
                    $0.tag = "ring"
                    $0.hidden = .function([], { [weak self] _ in
                        self?.displayTemplate.hasRing == false
                    })
                }
            )

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
                if let dict = config.Data["ring"] as? [String: Any],
                   let value = dict[$0.tag!] as? String {
                    $0.value = value
                }
            }

            <<< InlineColorPickerRow("ring_color") {
                $0.title = L10n.Watch.Configurator.Rows.Ring.Color.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor.green
                if let dict = config.Data["ring"] as? [String: Any],
                   let value = dict[$0.tag!] as? String {
                    $0.value = UIColor(hex: value)
                }
            }.onChange { picker in
                Current.Log.verbose("ring color: \(picker.value!.hexString(false))")
            }

            +++ Section(
                header: L10n.Watch.Configurator.Sections.Icon.header,
                footer: L10n.Watch.Configurator.Sections.Icon.footer
            ) {
                $0.tag = "icon"
                $0.hidden = .function([], { [weak self] _ in
                    self?.displayTemplate.hasImage == false
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
                if let dict = config.Data["icon"] as? [String: Any],
                   let value = dict[$0.tag!] as? String {
                    $0.value = MaterialDesignIcons(named: value)
                }
            }.cellUpdate({ [weak self] cell, row in
                if let value = row.value {
                    if let iconColorRow = self?.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                        cell.imageView?.image = value.image(
                            ofSize: CGSize(
                                width: CGFloat(30),
                                height: CGFloat(30)
                            ),
                            color: iconColorRow.value
                        )
                    }
                }
            }).onPresent { [weak self] _, to in
                to.selectableRowCellUpdate = { cell, row in
                    if let value = row.selectableValue {
                        if let iconColorRow = self?.form.rowBy(tag: "icon_color") as? InlineColorPickerRow {
                            cell.imageView?.image = value.image(
                                ofSize: CGSize(
                                    width: CGFloat(30),
                                    height: CGFloat(30)
                                ),
                                color: iconColorRow.value
                            )
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
                if let dict = config.Data["icon"] as? [String: Any],
                   let value = dict[$0.tag!] as? String {
                    $0.value = UIColor(hex: value)
                }
            }.onChange { [weak self] picker in
                Current.Log.verbose("icon color: \(picker.value!.hexString(false))")
                if let iconRow = self?.form.rowBy(tag: "icon") as? SearchPushRow<MaterialDesignIcons> {
                    if let value = iconRow.value {
                        iconRow.cell.imageView?.image = value.image(
                            ofSize: CGSize(
                                width: CGFloat(30),
                                height: CGFloat(30)
                            ),
                            color: picker.value
                        )
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

    enum RenderValueError: LocalizedError {
        case expectedFloat(value: Any)
        case outOfRange(value: Float)

        var errorDescription: String? {
            switch self {
            case let .expectedFloat(value: value):
                var displayType = String(describing: type(of: value))

                if displayType.lowercased().contains("string") {
                    displayType = "string"
                }

                return L10n.Watch.Configurator.PreviewError.notNumber(displayType, value)
            case let .outOfRange(value: value):
                return L10n.Watch.Configurator.PreviewError.outOfRange(value)
            }
        }
    }

    static func validate(result: Any, expectingPercentile: Bool) throws -> String {
        if expectingPercentile {
            if let number = WatchComplication.percentileNumber(from: result) {
                if !(0 ... 1 ~= number) {
                    throw RenderValueError.outOfRange(value: number)
                }
            } else {
                throw RenderValueError.expectedFloat(value: result)
            }
        }

        return String(describing: result)
    }

    func addComplicationTextAreaFormSection(location: ComplicationTextAreas) -> Section {
        let key = "textarea_" + location.slug
        var dataDict = [String: Any]()

        if let textAreasDict = config.Data["textAreas"] as? [String: [String: Any]],
           let slugDict = textAreasDict[location.slug] {
            dataDict = slugDict
        }

        let section = TemplateSection(
            header: location.label,
            footer: location.description,
            displayResult: { try Self.validate(result: $0, expectingPercentile: false) },
            server: server,
            initializeInput: {
                $0.tag = key + "_text"
                $0.title = location.label
                $0.add(rule: RuleRequired())
                $0.placeholder = "{{ states(\"weather.temperature\") }}"
                if let value = dataDict["text"] as? String {
                    $0.value = value
                }
            }, initializeSection: {
                $0.tag = location.slug
                $0.hidden = .function([], { [weak self] _ in
                    self?.displayTemplate.textAreas.map(\.slug).contains(location.slug) == false
                })
            }
        )

        section.append(InlineColorPickerRow {
            $0.tag = key + "_color"
            $0.title = L10n.Watch.Configurator.Rows.Color.title
            $0.isCircular = true
            $0.showsPaletteNames = true
            $0.value = UIColor.green
            if let value = dataDict["color"] as? String {
                $0.value = UIColor(hex: value)
            }
        }.onChange { picker in
            Current.Log.verbose("color for " + location.rawValue + ": \(picker.value!.hexString(false))")
        })

        return section
    }

    func reloadForm() {
        for section in form.allSections {
            section.evaluateHidden()
        }

        if displayTemplate.hasGauge, let gaugeType = form.rowBy(tag: "gauge_type") as? SegmentedRow<String> {
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

        for row in form.allRows {
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
}
