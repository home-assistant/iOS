import Shared
import SwiftUI

/// One behavior picker and whatever the picked behavior still needs to know: a navigation path, a
/// URL, an action and its data, an Assist pipeline, or a script.
///
/// A widget tile has two of these — what a tap on the tile does, and what a tap on its icon does —
/// so the rows are laid out for a `Section` the caller owns rather than bringing their own.
struct MagicItemActionSelectionView: View {
    let title: String
    @Binding var action: ItemAction?

    /// Prefilling reads the database for the chosen script, so the extra rows wait for it rather
    /// than rendering a picker with nothing in it.
    @State private var loaded = false
    @State private var navigationPath = ""
    @State private var urlPath = ""
    @State private var pipelineServerId: String?
    @State private var pipelineId: String?
    @State private var startListening = true
    @State private var script: HAAppEntity?
    @State private var performActionServerId: String?
    @State private var performActionId: String?
    @State private var performActionPayload = ""

    private var selected: ItemAction {
        action ?? .default
    }

    var body: some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            Menu {
                ForEach(ItemAction.allCases, id: \.id) { itemAction in
                    Button {
                        action = hydrated(itemAction)
                    } label: {
                        if selected.id == itemAction.id {
                            Label(itemAction.name, systemSymbol: .checkmark)
                        } else {
                            Text(itemAction.name)
                        }
                    }
                }
            } label: {
                Text(selected.name)
            }
        }
        .onAppear {
            guard !loaded else { return }
            prefill()
            loaded = true
        }
        if loaded, selected.id == ItemAction.navigate("").id {
            HStack {
                Text(verbatim: L10n.MagicItem.Action.NavigationPath.title)
                TextField(L10n.MagicItem.Action.NavigationPath.placeholder, text: $navigationPath)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: navigationPath) { newValue in
                        action = .navigate(newValue)
                    }
            }
        }
        if loaded, selected.id == ItemAction.url("").id {
            HStack {
                Text(verbatim: L10n.MagicItem.Action.Url.title)
                TextField(L10n.MagicItem.Action.Url.placeholder, text: $urlPath)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: urlPath) { newValue in
                        action = .url(newValue)
                    }
            }
        }
        if loaded, selected.id == ItemAction.performAction("", "", "").id {
            HStack {
                Text(verbatim: L10n.MagicItem.Action.PerformAction.title)
                ServerActionPicker(
                    selectedServerId: $performActionServerId,
                    selectedActionId: $performActionId
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onChange(of: performActionServerId) { _ in
                    updatePerformAction()
                }
                .onChange(of: performActionId) { _ in
                    updatePerformAction()
                }
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(verbatim: L10n.MagicItem.Action.PerformAction.Payload.title)
                TextField(
                    L10n.MagicItem.Action.PerformAction.Payload.placeholder,
                    text: $performActionPayload,
                    axis: .vertical
                )
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: performActionPayload) { _ in
                    updatePerformAction()
                }
                Text(verbatim: L10n.MagicItem.Action.PerformAction.Payload.footer)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        if loaded, selected.id == ItemAction.assist("", "", false).id {
            HStack {
                Text(verbatim: L10n.MagicItem.Action.Assist.Pipeline.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AssistPipelinePicker(
                    selectedServerId: $pipelineServerId,
                    selectedPipelineId: $pipelineId
                )
                .onChange(of: pipelineServerId) { _ in
                    updateAssistAction()
                }
                .onChange(of: pipelineId) { _ in
                    updateAssistAction()
                }
            }
            HStack {
                Text(verbatim: L10n.MagicItem.Action.Assist.StartListening.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle(isOn: $startListening, label: {})
                    .onChange(of: startListening) { _ in
                        updateAssistAction()
                    }
            }
        }
        if loaded, selected.id == ItemAction.runScript("", "").id {
            HStack {
                Text(verbatim: L10n.MagicItem.Action.Script.title)
                EntityPicker(selectedEntity: $script, domainFilter: [.script])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onChange(of: script) { newValue in
                        guard let newValue else { return }
                        action = .runScript(newValue.serverId, newValue.entityId)
                    }
            }
        }
    }

    /// Carries the details already on screen into a freshly picked behavior, so switching away and
    /// back doesn't blank the path or the pipeline the user typed.
    private func hydrated(_ itemAction: ItemAction) -> ItemAction {
        switch itemAction {
        case .navigate:
            return .navigate(navigationPath)
        case .url:
            return .url(urlPath)
        case .performAction:
            return .performAction(performActionServerId ?? "", performActionId ?? "", performActionPayload)
        case .assist:
            return .assist(pipelineServerId ?? "", pipelineId ?? "", startListening)
        case .runScript:
            return .runScript(script?.serverId ?? "", script?.entityId ?? "")
        case .default, .moreInfoDialog, .toggle, .nothing:
            return itemAction
        }
    }

    private func updateAssistAction() {
        guard let pipelineServerId, let pipelineId else { return }
        action = .assist(pipelineServerId, pipelineId, startListening)
    }

    private func updatePerformAction() {
        guard let performActionServerId, let performActionId else { return }
        action = .performAction(performActionServerId, performActionId, performActionPayload)
    }

    private func prefill() {
        switch selected {
        case let .navigate(path):
            navigationPath = path
        case let .url(urlString):
            urlPath = urlString
        case let .performAction(serverId, actionId, payload):
            performActionServerId = serverId
            performActionId = actionId
            performActionPayload = payload
        case let .runScript(serverId, scriptId):
            do {
                script = try HAAppEntity.config().first(where: { entity in
                    entity.serverId == serverId && entity.entityId == scriptId
                })
            } catch {
                Current.Log
                    .error("Failed to prefill script entity in magic item customization: \(error.localizedDescription)")
            }
        case let .assist(serverId, pipelineId, startListening):
            pipelineServerId = serverId
            self.pipelineId = pipelineId
            self.startListening = startListening
        case .default, .nothing, .moreInfoDialog, .toggle:
            break
        }
    }
}

#Preview {
    List {
        Section(L10n.MagicItem.action) {
            MagicItemActionSelectionView(
                title: L10n.MagicItem.Action.tapBehavior,
                action: .constant(.default)
            )
            MagicItemActionSelectionView(
                title: L10n.MagicItem.Action.iconTapBehavior,
                action: .constant(.navigate("/lovelace/0"))
            )
        }
    }
}
