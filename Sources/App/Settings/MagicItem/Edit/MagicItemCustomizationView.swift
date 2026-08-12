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
    @State private var showingStateColorRuleEditor = false
    @State private var editingStateColorRuleIndex: Int?

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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                    dismiss()
                } label: {
                    Text(mode == .add ? L10n.MagicItem.add : L10n.MagicItem.edit)
                }
            }
        }
        .onAppear {
            // Avoid nil customization object to prevent state values from crash
            preventNilCustomization()
            loadActionData()
            viewModel.loadMagicInfo()
        }
        .sheet(isPresented: $showingStateColorRuleEditor) {
            widgetStateColorRuleEditor
        }
    }

    private func save() {
        if Self.skipsConfirmation(context: context, item: viewModel.item) {
            viewModel.item.customization?.requiresConfirmation = false
        }

        if let action = viewModel.item.action {
            switch action {
            case .default, .nothing, .runScript, .assist, .moreInfoDialog:
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
                let entity = try HAAppEntity.config().first(where: { entity in
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
        case .default, .nothing, .moreInfoDialog:
            break
        }
        actionsLoaded = true
    }

    private func mainInformationView(info: MagicItem.Info) -> some View {
        Section {
            HStack(spacing: DesignSystem.Spaces.two) {
                if viewModel.item.type == .assistPipeline {
                    let iconColor: UIColor = if let iconColorHex = viewModel.item.customization?.iconColor {
                        UIColor(Color(hex: iconColorHex))
                    } else {
                        .haPrimary
                    }
                    Image(uiImage: MaterialDesignIcons.microphoneIcon.image(
                        ofSize: .init(width: 24, height: 24),
                        color: iconColor
                    ))
                } else {
                    IconPicker(
                        selectedIcon: .init(get: {
                            viewModel.item.icon(info: info)
                        }, set: { newIcon in
                            viewModel.item.customization?.icon = newIcon?.name
                            viewModel.item.customization?.iconIsCustomized = true
                        }),
                        selectedColor: .init(get: {
                            if let iconColorHex = viewModel.item.customization?.iconColor {
                                return Color(hex: iconColorHex)
                            } else {
                                return Color.haPrimary
                            }
                        }, set: { _ in
                            /* no-op */
                        })
                    )
                }
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
            Text(verbatim: L10n.MagicItem.DisplayText.title)
        }
    }

    @ViewBuilder
    private func customizationView(info: MagicItem.Info) -> some View {
        Section {
            ColorPicker(L10n.MagicItem.IconColor.title, selection: .init(get: {
                var color = Color.haPrimary
                if let configIconColor = viewModel.item.customization?.iconColor {
                    color = Color(hex: configIconColor)
                } else {
                    viewModel.item.customization?.iconColor = color.hex()
                }
                return color
            }, set: { newColor in
                viewModel.item.customization?.iconColor = newColor.hex()
            }), supportsOpacity: false)
            if context != .carPlay {
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

        if context == .widget {
            widgetStateColorsSection
        }
    }

    private var widgetStateColorsSection: some View {
        Section {
            ForEach(Array(stateColorRules.enumerated()), id: \.offset) { index, rule in
                Button {
                    editingStateColorRuleIndex = index
                    showingStateColorRuleEditor = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(stateColorRuleDescription(rule))
                                .foregroundStyle(.primary)
                            Text(stateColorRuleTargetDescription(rule))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(Color(hex: rule.color))
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.item.customization?.stateColorRules?.remove(at: index)
                    } label: {
                        Label(L10n.delete, systemSymbol: .trash)
                    }
                }
            }

            Button {
                editingStateColorRuleIndex = nil
                showingStateColorRuleEditor = true
            } label: {
                Label(L10n.MagicItem.StateColors.Add.title, systemSymbol: .plus)
            }
        } header: {
            Text(L10n.MagicItem.StateColors.title)
        } footer: {
            Text(L10n.MagicItem.StateColors.footer)
        }
    }

    private var widgetStateColorRuleEditor: some View {
        NavigationStack {
            WidgetStateColorRuleEditor(
                rule: editingStateColorRuleIndex.flatMap { stateColorRules[safe: $0] }
            ) { rule in
                if let editingStateColorRuleIndex,
                   stateColorRules.indices.contains(editingStateColorRuleIndex) {
                    viewModel.item.customization?.stateColorRules?[editingStateColorRuleIndex] = rule
                } else {
                    viewModel.item.customization?.stateColorRules = stateColorRules + [rule]
                }
            }
        }
    }

    private var stateColorRules: [WidgetStateColorRule] {
        viewModel.item.customization?.stateColorRules ?? []
    }

    private func stateColorRuleDescription(_ rule: WidgetStateColorRule) -> String {
        let comparison: String = switch rule.comparison {
        case .lessThan:
            L10n.MagicItem.StateColors.Comparison.lessThan
        case .greaterThan:
            L10n.MagicItem.StateColors.Comparison.greaterThan
        }
        return "\(comparison) \(rule.threshold.formatted())"
    }

    private func stateColorRuleTargetDescription(_ rule: WidgetStateColorRule) -> String {
        switch rule.target {
        case .state:
            L10n.MagicItem.StateColors.Target.State.title
        case .icon:
            L10n.MagicItem.StateColors.Target.Icon.title
        case .background:
            L10n.MagicItem.StateColors.Target.Background.title
        }
    }

    @ViewBuilder
    private var actionView: some View {
        if [.widget, .appIconShortcut].contains(context), actionsLoaded {
            Section(L10n.MagicItem.action) {
                HStack {
                    Text(verbatim: L10n.MagicItem.Action.onTap)
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
        // A watch sensor is only displayed — tapping it opens its details screen and runs nothing,
        // so there is no action to confirm. Neither does an area entry, which opens the area's
        // entities.
        if !Self.skipsConfirmation(context: context, item: viewModel.item),
           viewModel.item.type != .area,
           !(context == .watch && viewModel.item.isWatchDisplayOnly) {
            Section {
                Toggle(L10n.MagicItem.RequireConfirmation.title, isOn: .init(get: {
                    viewModel.item.customization?.requiresConfirmation ?? false
                }, set: { newValue in
                    viewModel.item.customization?.requiresConfirmation = newValue
                }))
            } footer: {
                if context == .widget {
                    Text(verbatim: L10n.Widgets.Custom.RequireConfirmation.footer)
                }
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
                Text(verbatim: L10n.MagicItem.Action.Assist.Pipeline.title)
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
            Text(verbatim: L10n.MagicItem.Action.Assist.StartListening.title)
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
            Text(verbatim: L10n.MagicItem.Action.Script.title)
            EntityPicker(selectedEntity: $viewModel.selectedEntity, domainFilter: [.script])
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onChange(of: viewModel.selectedEntity) { newValue in
                    guard let newValue else { return }
                    viewModel.item.action = .runScript(newValue.serverId, newValue.entityId)
                }
        }
    }

    /// An Assist item in CarPlay or on the watch starts an Assist session instead of running a
    /// service, so asking for confirmation first has nothing to confirm — and `MagicItemProvider`
    /// clears the flag on both Assist types anyway.
    private static func skipsConfirmation(context: MagicItemAddView.Context, item: MagicItem) -> Bool {
        [.carPlay, .watch].contains(context) && item.isAssist
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
