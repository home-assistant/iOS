import Shared
import SwiftUI

/// One behavior picker and whatever the picked behavior still needs to know: a navigation path, a
/// URL, an action and its data, an Assist pipeline, or a script.
///
/// A widget tile has two of these — what a tap on the tile does, and what a tap on its icon does —
/// so the rows are laid out for a `Section` the caller owns rather than bringing their own.
struct MagicItemActionSelectionView: View {
    let title: String
    /// The item the behavior is for. Its domain decides which behaviors are offered — "Toggle" and
    /// the on/off pair only where they can do something, the way the frontend's action editor
    /// drops "toggle" for an entity that can't be toggled — and what they are called ("Lock" and
    /// "Unlock" for a lock). A "perform action" behavior runs against its server, so that is the
    /// only server whose actions the picker offers.
    let item: MagicItem
    /// What leaving the picker on "Default" does for this item, so the entry can say so — "Default
    /// (More info)", "Default (Toggle)" — the way the frontend's action editor labels its own.
    let defaultAction: ItemAction
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
    @State private var performActionId: String?
    @State private var performActionPayload = ""

    /// A retired choice — "nothing", which items saved with it still carry — reads as the default
    /// it now behaves as, so the picker never shows a behavior it no longer offers.
    private var selected: ItemAction {
        guard let action, !action.isRetired else { return .default }
        return action
    }

    private var offeredActions: [ItemAction] {
        ItemAction.offered(for: item, selected: selected)
    }

    var body: some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            Menu {
                ForEach(offeredActions, id: \.id) { itemAction in
                    Button {
                        action = hydrated(itemAction)
                    } label: {
                        if selected.id == itemAction.id {
                            Label(name(of: itemAction), systemSymbol: .checkmark)
                        } else {
                            Text(name(of: itemAction))
                        }
                    }
                }
            } label: {
                Text(name(of: selected))
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
                    serverId: item.serverId,
                    selectedActionId: $performActionId
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
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

    /// "Default" alone says nothing about what a tap will do, so it carries the resolved behavior
    /// along; every other behavior is its own name, in the item's domain's words.
    private func name(of itemAction: ItemAction) -> String {
        if itemAction.id == ItemAction.default.id {
            return ItemAction.defaultName(resolvingTo: defaultAction.name(for: item.domain))
        }
        return itemAction.name(for: item.domain)
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
            return .performAction(item.serverId, performActionId ?? "", performActionPayload)
        case .assist:
            return .assist(pipelineServerId ?? "", pipelineId ?? "", startListening)
        case .runScript:
            return .runScript(script?.serverId ?? "", script?.entityId ?? "")
        case .default, .moreInfoDialog, .toggle, .turnOn, .turnOff, .nothing:
            return itemAction
        }
    }

    private func updateAssistAction() {
        guard let pipelineServerId, let pipelineId else { return }
        action = .assist(pipelineServerId, pipelineId, startListening)
    }

    /// Written even before an action is picked, so data typed first survives the trip back — the
    /// same half-filled state `hydrated(_:)` already stores the moment the behavior is chosen.
    private func updatePerformAction() {
        action = .performAction(item.serverId, performActionId ?? "", performActionPayload)
    }

    private func prefill() {
        switch selected {
        case let .navigate(path):
            navigationPath = path
        case let .url(urlString):
            urlPath = urlString
        case let .performAction(_, actionId, payload):
            performActionId = actionId
            performActionPayload = payload
        case let .runScript(scriptServerId, scriptId):
            do {
                script = try HAAppEntity.config().first(where: { entity in
                    entity.serverId == scriptServerId && entity.entityId == scriptId
                })
            } catch {
                Current.Log
                    .error("Failed to prefill script entity in magic item customization: \(error.localizedDescription)")
            }
        case let .assist(assistServerId, pipelineId, startListening):
            pipelineServerId = assistServerId
            self.pipelineId = pipelineId
            self.startListening = startListening
        case .default, .nothing, .moreInfoDialog, .toggle, .turnOn, .turnOff:
            break
        }
    }
}

#Preview {
    let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
    let lock = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
    List {
        Section(L10n.MagicItem.action) {
            MagicItemActionSelectionView(
                title: L10n.MagicItem.Action.tapBehavior,
                item: light,
                defaultAction: light.defaultTapAction,
                action: .constant(.default)
            )
            MagicItemActionSelectionView(
                title: L10n.MagicItem.Action.iconTapBehavior,
                item: light,
                defaultAction: light.defaultIconAction,
                action: .constant(.navigate("/lovelace/0"))
            )
        }
        Section(L10n.MagicItem.action) {
            MagicItemActionSelectionView(
                title: L10n.MagicItem.Action.iconTapBehavior,
                item: lock,
                defaultAction: lock.defaultIconAction,
                action: .constant(.turnOff)
            )
        }
    }
}
