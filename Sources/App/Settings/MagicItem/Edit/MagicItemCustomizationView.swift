import Shared
import SwiftUI

struct MagicItemCustomizationView: View {
    enum Mode {
        case add
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemEditViewModel

    @State private var useCustomColors = false

    /// Context in which the screen will be presented, editing existent Magic Item or adding new
    let mode: Mode
    let displayAction: Bool
    let addItem: (MagicItem) -> Void

    init(
        mode: Mode,
        displayAction: Bool,
        item: MagicItem,
        addItem: @escaping (MagicItem) -> Void
    ) {
        self.mode = mode
        self._viewModel = .init(wrappedValue: .init(item: item))
        self.addItem = addItem
        self.displayAction = displayAction
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

    private func mainInformationView(info: MagicItem.Info) -> some View {
        Section {
            HStack {
                HStack {
                    Image(uiImage: MaterialDesignIcons(serversideValueNamed: info.iconName, fallback: .gridIcon).image(ofSize: .init(width: 24, height: 24), color: .label))
                }
                .frame(width: 24, height: 24)
                TextField(viewModel.info?.name ?? viewModel.item.id, text: .init(get: {
                    viewModel.item.displayText ?? ""
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
        if displayAction {
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
        Section {
            Toggle(L10n.MagicItem.RequireConfirmation.title, isOn: .init(get: {
                viewModel.item.customization?.requiresConfirmation ?? true
            }, set: { newValue in
                viewModel.item.customization?.requiresConfirmation = newValue
            }))
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
                AssistPipelinePicker { serverId, pipeline in
                    viewModel.item.action = .assist(serverId, pipeline.id, viewModel.startListeningAssistAction)
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
            EntityPicker(domainFilter: .script) { entity in
                viewModel.item.action = .runScript(entity.serverId, entity.entityId)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
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
        displayAction: true,
        item: .init(id: "script.unlock_door", serverId: "1", type: .script)
    ) { _ in
    }
}
