import Shared
import SwiftUI

struct MagicItemCustomizationView: View {
    enum Mode {
        case add
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemCustomizationViewModel

    @State private var useCustomColors = false

    // Toggle to wait until actions are prefilled in case of editing magic item, then it can show the action items
    @State private var actionsLoaded = false

    /// Context in which the screen will be presented, editing existent Magic Item or adding new
    let mode: Mode
    let context: MagicItemAddView.Context
    let addItem: (MagicItem) -> Void

    init(
        mode: Mode,
        context: MagicItemAddView.Context,
        item: MagicItem,
        addItem: @escaping (MagicItem) -> Void
    ) {
        self.mode = mode
        self.context = context
        self._viewModel = .init(wrappedValue: .init(item: item))
        self.addItem = addItem
    }

    var body: some View {
        List {
            if let info = viewModel.info {
                mainInformationView(info: info)
                customizationView(info: info)
                actionView
            }
        }
        .onChange(of: viewModel.info) { newValue in
            guard let newValue else { return }
            useCustomColors = newValue.customization?.backgroundColor != nil || newValue.customization?.textColor != nil
        }
        .onChange(of: useCustomColors) { newValue in
            if newValue {
                viewModel.item.customization?.backgroundColor = viewModel.item.customization?.backgroundColor ?? UIColor
                    .black.hexString()
                viewModel.item.customization?.textColor = viewModel.item.customization?.textColor ?? UIColor.white
                    .hexString()
            } else {
                viewModel.item.customization?.backgroundColor = nil
                viewModel.item.customization?.textColor = nil
            }
        }
        .toolbar {
            Button {
                save()
                dismiss()
            } label: {
                Text(mode == .add ? L10n.MagicItem.add : L10n.MagicItem.edit)
            }
        }
        .onAppear {
            // Avoid nil customization object to prevent state values from crash
            preventNilCustomization()
            loadActionData()
            viewModel.loadMagicInfo()
        }
    }

    private func save() {
        if let action = viewModel.item.action {
            switch action {
            case .default, .toggle, .nothing, .runScript, .assist:
                // No update needed
                break
            case .navigate:
                viewModel.item.action = .navigate(viewModel.navigationPathAction)
            }
        }

        addItem(viewModel.item)
    }

    private func loadActionData() {
        guard let existentAction = viewModel.item.action else { return }
        switch existentAction {
        case let .navigate(path):
            viewModel.navigationPathAction = path
        case let .runScript(serverId, scriptId):
            do {
                let entity = try HAAppEntity.config()?.first(where: { entity in
                    entity.serverId == serverId && entity.entityId == scriptId
                })
                viewModel.selectedEntity = entity
            } catch {
                Current.Log
                    .error("Failed to prefill script entity in magic item customization: \(error.localizedDescription)")
            }
        case let .assist(serverId, pipelineId, startListening):
            viewModel.startListeningAssistAction = startListening
            viewModel.selectedPipelineId = pipelineId
            viewModel.selectedServerIdForPipeline = serverId
        case .default, .toggle, .nothing:
            break
        }
        actionsLoaded = true
    }

    private func mainInformationView(info: MagicItem.Info) -> some View {
        Section {
            HStack(spacing: Spaces.two) {
                IconPicker(
                    selectedIcon: .init(get: {
                        viewModel.item.icon(info: info)
                    }, set: { newIcon in
                        viewModel.item.customization?.icon = newIcon?.name
                    }),
                    selectedColor: .init(get: {
                        if let iconColorHex = viewModel.item.customization?.iconColor {
                            return Color(hex: iconColorHex)
                        } else {
                            return Color(uiColor: Asset.Colors.haPrimary.color)
                        }
                    }, set: { _ in
                        /* no-op */
                    })
                )
                TextField(viewModel.item.name(info: info), text: .init(get: {
                    viewModel.item.name(info: info)
                }, set: { newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.item.displayText = nil
                    } else {
                        viewModel.item.displayText = newValue
                    }
                }))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text(L10n.MagicItem.DisplayText.title)
        } footer: {
            if viewModel.item.type == .script {
                Text(L10n.MagicItem.NameAndIcon.footer)
            }
            if viewModel.item.type == .scene {
                Text(L10n.MagicItem.NameAndIcon.Footer.scenes)
            }
        }
    }

    @ViewBuilder
    private func customizationView(info: MagicItem.Info) -> some View {
        Section {
            ColorPicker(L10n.MagicItem.IconColor.title, selection: .init(get: {
                var color = Color(uiColor: Asset.Colors.haPrimary.color)
                if let configIconColor = viewModel.item.customization?.iconColor {
                    color = Color(hex: configIconColor)
                } else {
                    viewModel.item.customization?.iconColor = color.hex()
                }
                return color
            }, set: { newColor in
                viewModel.item.customization?.iconColor = newColor.hex()
            }), supportsOpacity: false)
            Toggle(L10n.MagicItem.UseCustomColors.title, isOn: $useCustomColors)
            if useCustomColors {
                ColorPicker(L10n.MagicItem.BackgroundColor.title, selection: .init(get: {
                    Color(hex: viewModel.item.customization?.backgroundColor)
                }, set: { newColor in
                    viewModel.item.customization?.backgroundColor = newColor.hex()
                }), supportsOpacity: false)
                ColorPicker(L10n.MagicItem.TextColor.title, selection: .init(get: {
                    Color(hex: viewModel.item.customization?.textColor)
                }, set: { newColor in
                    viewModel.item.customization?.textColor = newColor.hex()
                }), supportsOpacity: false)
            }
        }
    }

    @ViewBuilder
    private var actionView: some View {
        if context == .widget, actionsLoaded {
            Section(L10n.MagicItem.action) {
                HStack {
                    Text(L10n.MagicItem.Action.onTap)
                    Spacer()
                    Menu {
                        ForEach(ItemAction.allCases, id: \.id) { itemAction in
                            Button {
                                viewModel.item.action = itemAction
                            } label: {
                                let selectedAction = viewModel.item.action ?? ItemAction.default
                                if selectedAction.id == itemAction.id {
                                    Label(itemAction.name, systemSymbol: .checkmark)
                                } else {
                                    Text(itemAction.name)
                                }
                            }
                        }

                    } label: {
                        Text(viewModel.item.action?.name ?? ItemAction.default.name)
                    }
                }
            }

            if viewModel.item.action?.id == ItemAction.navigate("").id {
                navigateActionTextfield
            }
            if viewModel.item.action?.id == ItemAction.assist("", "", false).id {
                assistActionDetails
            }
            if viewModel.item.action?.id == ItemAction.runScript("", "").id {
                scriptActionDetails
            }
        }

        // TODO: Make widgets support confirmation before execution
        if context != .widget {
            Section {
                Toggle(L10n.MagicItem.RequireConfirmation.title, isOn: .init(get: {
                    viewModel.item.customization?.requiresConfirmation ?? true
                }, set: { newValue in
                    viewModel.item.customization?.requiresConfirmation = newValue
                }))
            }
        }
    }

    private var navigateActionTextfield: some View {
        Section(L10n.MagicItem.Action.NavigationPath.title) {
            TextField(L10n.MagicItem.Action.NavigationPath.placeholder, text: $viewModel.navigationPathAction)
        }
    }

    @ViewBuilder
    private var assistActionDetails: some View {
        Section(L10n.MagicItem.Action.Assist.title) {
            HStack {
                Text(L10n.MagicItem.Action.Assist.Pipeline.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AssistPipelinePicker(
                    selectedServerId: $viewModel.selectedServerIdForPipeline,
                    selectedPipelineId: $viewModel.selectedPipelineId
                )
                .onChange(of: viewModel.selectedServerIdForPipeline) { newValue in
                    guard let newValue, let selectedPipelineId = viewModel.selectedPipelineId else { return }
                    viewModel.item.action = .assist(
                        newValue,
                        selectedPipelineId,
                        viewModel.startListeningAssistAction
                    )
                }
                .onChange(of: viewModel.selectedPipelineId) { newValue in
                    guard let newValue,
                          let selectedServerIdForPipeline = viewModel.selectedServerIdForPipeline else { return }
                    viewModel.item.action = .assist(
                        selectedServerIdForPipeline,
                        newValue,
                        viewModel.startListeningAssistAction
                    )
                }
            }
        }
        HStack {
            Text(L10n.MagicItem.Action.Assist.StartListening.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(isOn: $viewModel.startListeningAssistAction, label: {})
                .onChange(of: viewModel.startListeningAssistAction) { newValue in
                    if case let .assist(serverId, pipelineId, _) = viewModel.item.action {
                        viewModel.item.action = .assist(serverId, pipelineId, newValue)
                    }
                }
        }
    }

    private var scriptActionDetails: some View {
        HStack {
            Text(L10n.MagicItem.Action.Script.title)
            EntityPicker(selectedEntity: $viewModel.selectedEntity, domainFilter: .script)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onChange(of: viewModel.selectedEntity) { newValue in
                    guard let newValue else { return }
                    viewModel.item.action = .runScript(newValue.serverId, newValue.entityId)
                }
        }
    }

    private func preventNilCustomization() {
        if viewModel.item.customization == nil {
            viewModel.item.customization = .init()
        }
    }
}

#Preview {
    MagicItemCustomizationView(
        mode: .add,
        context: .widget,
        item: .init(id: "script.unlock_door", serverId: "1", type: .script)
    ) { _ in
    }
}
