import ColorPickerRow
import Eureka
import Foundation
import PromiseKit
import RealmSwift
import Shared
import SwiftUI
import UIKit
import ViewRow

class ActionConfigurator: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var action = Action() {
        didSet {
            updatePreviews()
        }
    }

    private var newAction: Bool = true
    private(set) var shouldSave: Bool = false
    private(set) var shouldOpenAutomationEditor: Bool = false
    private var preview = ActionPreview(frame: CGRect(x: 0, y: 0, width: 169, height: 55))

    private let useCustomColorsTag = "useCustomColors"

    convenience init(action: Action?) {
        self.init()

        self.isModalInPresentation = true

        if let action {
            self.action = Action(value: action)
            self.newAction = false
        } else if let firstServer = Current.servers.all.first {
            self.action.serverIdentifier = firstServer.identifier.rawValue
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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

        form +++ ViewRow<ActionPreview>("preview") { [weak self] row in
            row.hidden = Condition.function(["showInWatch"], { _ in
                !(self?.action.showInWatch ?? true)
            })
        }.cellSetup { [weak self] cell, _ in
            guard let self else { return }
            cell.backgroundColor = UIColor.clear
            cell.preservesSuperviewLayoutMargins = false
            updatePreviews()
            cell.view = preview
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

        let visuals = Section()

        if action.canConfigure(\Action.Text) || action.isServerControlled {
            let section: Eureka.Section

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

        firstSection <<< ServerSelectRow("server") {
            $0.disabled = .init(booleanLiteral: !action.canConfigure(\Action.serverIdentifier))

            if let server = Current.servers.server(forServerIdentifier: action.serverIdentifier) {
                $0.value = .server(server)
            } else {
                $0.value = Current.servers.all.first.flatMap { .server($0) }
            }

            $0.onChange { [action] row in
                if case let .server(server) = row.value {
                    action.serverIdentifier = server.identifier.rawValue
                }
            }
        }

        if !Current.isCatalyst {
            firstSection <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Actions.CarPlay.Available.title
                $0.value = action.showInCarPlay
                $0.disabled = .init(booleanLiteral: !action.canConfigure(\Action.showInCarPlay))
            }.onChange { row in
                if let value = row.value {
                    self.action.showInCarPlay = value
                }
            }

            firstSection <<< SwitchRow("showInWatch") {
                $0.title = L10n.SettingsDetails.Actions.Watch.Available.title
                $0.value = action.showInWatch
                $0.disabled = .init(booleanLiteral: !action.canConfigure(\Action.showInWatch))
            }.onChange { row in
                if let value = row.value {
                    self.action.showInWatch = value
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
            }.cellUpdate({ cell, row in
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
            }.onChange { picker in
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
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(
                    barButtonSystemItem: .save,
                    target: self,
                    action: #selector(save)
                ),
            ]

            if action.triggerType == .scene {
                let keys = ["text_color", "background_color", "icon_color"]
                let list: String

                list = ListFormatter.localizedString(byJoining: keys)

                visuals.footer = HeaderFooterView(
                    stringLiteral: L10n.ActionsConfigurator.VisualSection.sceneHintFooter(list)
                )
            }

            form.append(visuals)
        }

        let customSection = Section()
        form +++ customSection
        customSection <<< SwitchRow(useCustomColorsTag) {
            $0.title = L10n.SettingsDetails.Actions.UseCustomColors.title
            $0.value = action.useCustomColors
            $0.disabled = .init(booleanLiteral: !action.canConfigure(\Action.useCustomColors))
        }.onChange { row in
            if let value = row.value {
                self.action.useCustomColors = value
                self.updatePreviews()
            }
        }

        if action.canConfigure(\Action.TextColor) {
            customSection <<< InlineColorPickerRow("text_color") {
                $0.title = L10n.ActionsConfigurator.Rows.TextColor.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor(hex: self.action.TextColor)
                $0.hidden = .function([useCustomColorsTag], { _ in
                    !self.action.useCustomColors
                })
            }.onChange { row in
                if let value = row.value {
                    self.action.TextColor = value.hexString()
                    self.updatePreviews()
                }
            }
        }

        if action.canConfigure(\Action.BackgroundColor) {
            customSection <<< InlineColorPickerRow("background_color") {
                $0.title = L10n.ActionsConfigurator.Rows.BackgroundColor.title
                $0.isCircular = true
                $0.showsPaletteNames = true
                $0.value = UIColor(hex: self.action.BackgroundColor)
                $0.hidden = .function([useCustomColorsTag], { _ in
                    !self.action.useCustomColors
                })
            }.onChange { row in
                if let value = row.value {
                    self.action.BackgroundColor = value.hexString()
                    self.updatePreviews()
                }
            }
        }

        form +++ Section(header: L10n.ActionsConfigurator.Action.title, footer: L10n.ActionsConfigurator.Action.footer)
            <<< ButtonRow {
                $0.title = L10n.ActionsConfigurator.Action.createAutomation
            }.onCellSelection({ [weak self] _, _ in
                self?.saveAndAutomate()
            })
    }

    @objc
    func getInfoAction(_ sender: Any) {
        Current.Log.verbose("getInfoAction hit, open docs page!")
    }

    @objc
    func save(_ sender: Any) {
        Current.Log.verbose("Go back hit, check for validation")

        if form.validate().count == 0 {
            Current.Log.verbose("Category form is valid, calling dismiss callback!")
            shouldSave = true
            onDismissCallback?(self)
        }
    }

    private func saveAndAutomate() {
        if form.validate().count == 0 {
            Current.Log.verbose("Category form is valid, calling dismiss callback!")
            if !action.isServerControlled {
                shouldSave = true
            }
            shouldOpenAutomationEditor = true
            onDismissCallback?(self)
        }
    }

    private func updatePreviews() {
        if action.Name.isEmpty, newAction {
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
    var action: Action?

    private let stackView = UIStackView()

    override func layoutSubviews() {
        super.layoutSubviews()

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leftAnchor.constraint(equalTo: leftAnchor),
            stackView.rightAnchor.constraint(equalTo: rightAnchor),
        ])

        setup(action)
    }

    func setup(_ action: Action?) {
        self.action = action

        for subview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        guard let action else { return }
        let previewView = UIHostingController(rootView: WidgetPreviewView(action: action))
        stackView.addArrangedSubview(previewView.view)
    }
}

#Preview {
    VStack {
        WidgetPreviewView(action: Action())
    }
}

struct WidgetPreviewView: View {
    let action: Action
    var body: some View {
        VStack {
            WidgetBasicView(
                model: .init(
                    id: action.ID,
                    title: action.Text,
                    subtitle: nil,
                    interactionType: .widgetURL(URL(string: "https://google.com")!),
                    icon: MaterialDesignIcons(named: action.IconName),
                    textColor: Color(uiColor: .init(hex: action.TextColor)),
                    iconColor: Color(uiColor: .init(hex: action.IconColor)),
                    backgroundColor: Color(uiColor: .init(hex: action.BackgroundColor)),
                    useCustomColors: action.useCustomColors
                ),
                sizeStyle: .condensed
            )
            .padding()
            .frame(width: 340, height: 100)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }
}
