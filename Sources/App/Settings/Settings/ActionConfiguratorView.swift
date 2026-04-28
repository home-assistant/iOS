import PromiseKit
import RealmSwift
import Shared
import SwiftUI

/// View model that holds the mutable fields of an `Action` being edited.
///
/// Backing `Action` is a Realm `Object`, so we mirror its editable fields onto
/// `@Published` properties to make SwiftUI redraws reliable and keep Realm
/// writes out of the view body.
final class ActionConfiguratorViewModel: ObservableObject {
    @Published var name: String
    @Published var text: String
    @Published var iconName: String
    @Published var iconColor: String
    @Published var textColor: String
    @Published var backgroundColor: String
    @Published var useCustomColors: Bool
    @Published var serverIdentifier: String

    private let sourceAction: Action
    let isNewAction: Bool

    var isServerControlled: Bool { sourceAction.isServerControlled }
    var triggerType: Action.TriggerType { sourceAction.triggerType }
    var showInWatch: Bool { sourceAction.showInWatch }

    init(action: Action?) {
        if let action {
            let copy = Action(value: action)
            self.sourceAction = copy
            self.isNewAction = false
        } else {
            let fresh = Action()
            if let firstServer = Current.servers.all.first {
                fresh.serverIdentifier = firstServer.identifier.rawValue
            }
            self.sourceAction = fresh
            self.isNewAction = true
        }
        self.name = sourceAction.Name
        self.text = sourceAction.Text
        self.iconName = sourceAction.IconName
        self.iconColor = sourceAction.IconColor
        self.textColor = sourceAction.TextColor
        self.backgroundColor = sourceAction.BackgroundColor
        self.useCustomColors = sourceAction.useCustomColors

        // Fall back to the first available server if the stored identifier is empty
        // or points to a server that no longer exists. Common for actions imported from
        // older single-server installs.
        let allServerIds = Set(Current.servers.all.map(\.identifier.rawValue))
        if sourceAction.serverIdentifier.isEmpty || !allServerIds.contains(sourceAction.serverIdentifier) {
            self.serverIdentifier = Current.servers.all.first?.identifier.rawValue ?? sourceAction.serverIdentifier
        } else {
            self.serverIdentifier = sourceAction.serverIdentifier
        }
    }

    func canConfigure(_ keyPath: PartialKeyPath<Action>) -> Bool {
        sourceAction.canConfigure(keyPath)
    }

    /// Returns an unmanaged `Action` with the view model values applied. Safe to
    /// hand to the `onSave` callback for Realm persistence.
    func buildAction() -> Action {
        let result = Action(value: sourceAction)
        result.Name = name
        result.Text = text
        result.IconName = iconName
        result.IconColor = iconColor
        result.TextColor = textColor
        result.BackgroundColor = backgroundColor
        result.useCustomColors = useCustomColors
        result.serverIdentifier = serverIdentifier
        return result
    }
}

/// SwiftUI editor for a legacy `Action`. Replaces the Eureka-based `ActionConfigurator`.
///
/// The caller is responsible for persisting the resulting `Action` to Realm when
/// `onSave` is invoked.
struct ActionConfiguratorView: View {
    @StateObject private var viewModel: ActionConfiguratorViewModel

    @Environment(\.dismiss) private var dismiss

    private let onSave: (Action, _ openAutomationEditor: Bool) -> Void

    init(
        action: Action?,
        onSave: @escaping (Action, _ openAutomationEditor: Bool) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: ActionConfiguratorViewModel(action: action))
        self.onSave = onSave
    }

    var body: some View {
        Form {
            previewSection
            nameAndServerSection
            textSection
            visualsSection
            customColorsSection
            executeSection
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasEditableFields {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.saveLabel) {
                        save(openAutomationEditor: false)
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var title: String {
        if viewModel.name.isEmpty, viewModel.isNewAction {
            return L10n.ActionsConfigurator.title
        }
        return viewModel.name
    }

    private var isValid: Bool {
        !viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !viewModel.text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasEditableFields: Bool {
        viewModel.canConfigure(\Action.Name)
            || viewModel.canConfigure(\Action.Text)
            || viewModel.canConfigure(\Action.IconName)
            || viewModel.canConfigure(\Action.IconColor)
            || viewModel.canConfigure(\Action.TextColor)
            || viewModel.canConfigure(\Action.BackgroundColor)
            || viewModel.canConfigure(\Action.useCustomColors)
    }

    // MARK: - Sections

    @ViewBuilder
    private var previewSection: some View {
        if viewModel.showInWatch {
            Section {
                WidgetPreviewView(viewModel: viewModel)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var nameAndServerSection: some View {
        Section {
            LabeledField(title: L10n.ActionsConfigurator.Rows.Name.title) {
                TextField(L10n.ActionsConfigurator.Rows.Name.title, text: $viewModel.name)
                    .disabled(!viewModel.canConfigure(\Action.Name))
                    .multilineTextAlignment(.trailing)
            }

            // When the action is server-controlled, Text isn't editable, but still display it here
            // to match the old layout.
            if !viewModel.canConfigure(\Action.Text), viewModel.isServerControlled {
                LabeledField(title: L10n.ActionsConfigurator.Rows.Text.title) {
                    TextField(L10n.ActionsConfigurator.Rows.Text.title, text: $viewModel.text)
                        .disabled(true)
                        .multilineTextAlignment(.trailing)
                }
            }

            ActionServerPicker(
                selectedServerId: $viewModel.serverIdentifier,
                isDisabled: !viewModel.canConfigure(\Action.serverIdentifier)
            )
        }
    }

    @ViewBuilder
    private var textSection: some View {
        if viewModel.canConfigure(\Action.Text) {
            Section {
                LabeledField(title: L10n.ActionsConfigurator.Rows.Text.title) {
                    TextField(L10n.ActionsConfigurator.Rows.Text.title, text: $viewModel.text)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var visualsSection: some View {
        let canConfigureIcon = viewModel.canConfigure(\Action.IconName)
        let canConfigureIconColor = viewModel.canConfigure(\Action.IconColor)

        if !canConfigureIcon, !canConfigureIconColor {
            Section {
                switch viewModel.triggerType {
                case .event:
                    Text(L10n.ActionsConfigurator.VisualSection.serverDefined)
                        .foregroundStyle(.secondary)
                case .scene:
                    Text(L10n.ActionsConfigurator.VisualSection.sceneDefined)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Section {
                if canConfigureIcon {
                    iconPickerRow
                }
                if canConfigureIconColor {
                    ColorPicker(
                        L10n.ActionsConfigurator.Rows.IconColor.title,
                        selection: Binding(
                            get: { Color(hex: viewModel.iconColor) },
                            set: { newColor in
                                viewModel.iconColor = newColor.hex() ?? viewModel.iconColor
                            }
                        ),
                        supportsOpacity: false
                    )
                }
            } footer: {
                if viewModel.triggerType == .scene {
                    Text(L10n.ActionsConfigurator.VisualSection.sceneHintFooter(
                        ListFormatter.localizedString(byJoining: ["text_color", "background_color", "icon_color"])
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private var iconPickerRow: some View {
        HStack {
            Text(L10n.ActionsConfigurator.Rows.Icon.title)
            Spacer()
            IconPicker(
                selectedIcon: Binding(
                    get: { MaterialDesignIcons(named: viewModel.iconName) },
                    set: { newIcon in
                        if let newIcon {
                            viewModel.iconName = newIcon.name
                        }
                    }
                ),
                selectedColor: Binding(
                    get: { Color(hex: viewModel.iconColor) },
                    set: { _ in /* no-op */ }
                )
            )
        }
    }

    @ViewBuilder
    private var customColorsSection: some View {
        let canConfigureTextColor = viewModel.canConfigure(\Action.TextColor)
        let canConfigureBackgroundColor = viewModel.canConfigure(\Action.BackgroundColor)
        let canConfigureUseCustom = viewModel.canConfigure(\Action.useCustomColors)

        if canConfigureUseCustom || canConfigureTextColor || canConfigureBackgroundColor {
            Section {
                Toggle(L10n.SettingsDetails.Actions.UseCustomColors.title, isOn: $viewModel.useCustomColors)
                    .disabled(!canConfigureUseCustom)

                if viewModel.useCustomColors {
                    if canConfigureTextColor {
                        ColorPicker(
                            L10n.ActionsConfigurator.Rows.TextColor.title,
                            selection: Binding(
                                get: { Color(hex: viewModel.textColor) },
                                set: { newColor in
                                    viewModel.textColor = newColor.hex() ?? viewModel.textColor
                                }
                            ),
                            supportsOpacity: false
                        )
                    }
                    if canConfigureBackgroundColor {
                        ColorPicker(
                            L10n.ActionsConfigurator.Rows.BackgroundColor.title,
                            selection: Binding(
                                get: { Color(hex: viewModel.backgroundColor) },
                                set: { newColor in
                                    viewModel.backgroundColor = newColor.hex() ?? viewModel.backgroundColor
                                }
                            ),
                            supportsOpacity: false
                        )
                    }
                }
            }
        }
    }

    private var executeSection: some View {
        Section {
            Button {
                save(openAutomationEditor: true)
            } label: {
                Label(
                    L10n.ActionsConfigurator.Action.createAutomation,
                    systemSymbol: .arrowUpForwardSquare
                )
            }
            .disabled(!isValid)
        } header: {
            Text(L10n.ActionsConfigurator.Action.title)
        } footer: {
            Text(L10n.ActionsConfigurator.Action.footer)
        }
    }

    // MARK: - Save

    private func save(openAutomationEditor: Bool) {
        guard isValid else { return }
        onSave(viewModel.buildAction(), openAutomationEditor)
        dismiss()
    }
}

// MARK: - Helpers

private struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
    }
}

/// SwiftUI replacement for the Eureka `ServerSelectRow` that writes the chosen
/// server identifier into a binding.
struct ActionServerPicker: View {
    @Binding var selectedServerId: String
    let isDisabled: Bool

    @StateObject private var observer = ServersObserver()

    var body: some View {
        Picker(L10n.Settings.ServerSelect.title, selection: $selectedServerId) {
            ForEach(observer.servers, id: \.identifier) { server in
                Text(server.info.name)
                    .tag(server.identifier.rawValue)
            }
        }
        .pickerStyle(.menu)
        .disabled(isDisabled)
    }
}

// MARK: - Widget Preview

struct WidgetPreviewView: View {
    @ObservedObject var viewModel: ActionConfiguratorViewModel

    var body: some View {
        VStack {
            WidgetBasicButtonView(
                model: .init(
                    id: UUID().uuidString,
                    title: viewModel.text,
                    subtitle: nil,
                    interactionType: .widgetURL(URL(string: "homeassistant://perform_action")!),
                    icon: MaterialDesignIcons(named: viewModel.iconName),
                    textColor: Color(hex: viewModel.textColor),
                    iconColor: Color(hex: viewModel.iconColor),
                    backgroundColor: Color(hex: viewModel.backgroundColor),
                    useCustomColors: viewModel.useCustomColors
                ),
                sizeStyle: .compact,
                tinted: false
            )
            .padding()
            .frame(width: 340, height: 100)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        ActionConfiguratorView(action: nil, onSave: { _, _ in })
    }
}
