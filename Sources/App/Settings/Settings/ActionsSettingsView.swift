import PromiseKit
import RealmSwift
import Shared
import SwiftUI

/// SwiftUI replacement for the legacy Eureka "Actions" settings screen.
///
/// Displays:
/// - A disclaimer about legacy actions.
/// - The list of locally-created actions (reorderable / deletable).
/// - Scene actions (toggle + customize navigation).
/// - Server-controlled actions (read-only).
/// - A button to refresh server actions.
struct ActionsSettingsView: View {
    @StateObject private var viewModel = ActionsSettingsViewModel()

    @State private var newAction: Action?
    @State private var editingAction: Action?
    @State private var editingSceneAction: Action?

    var body: some View {
        List {
            disclaimerSection
            localActionsSection
            scenesSection
            serverActionsSection
            serverUpdateSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.SettingsDetails.LegacyActions.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    if hasAnyEditableActions {
                        EditButton()
                    }
                    Button {
                        newAction = Action()
                    } label: {
                        Image(systemSymbol: .plus)
                    }
                }
            }
        }
        .sheet(item: $newAction) { action in
            ActionEditorSheet(action: action, isNew: true) { updated, openAutomationEditor in
                handleSheetSave(updated: updated, openAutomationEditor: openAutomationEditor)
            }
        }
        .sheet(item: $editingAction) { action in
            ActionEditorSheet(action: action, isNew: false) { updated, openAutomationEditor in
                handleSheetSave(updated: updated, openAutomationEditor: openAutomationEditor)
            }
        }
        .sheet(item: $editingSceneAction) { action in
            ActionEditorSheet(action: action, isNew: false) { updated, _ in
                viewModel.save(action: updated)
            }
        }
    }

    private var hasAnyEditableActions: Bool {
        !viewModel.localActions.isEmpty
    }

    // MARK: - Sections

    private var disclaimerSection: some View {
        Section {
            Text(L10n.LegacyActions.disclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var localActionsSection: some View {
        Section {
            if !viewModel.localActions.isEmpty {
                ForEach(viewModel.localActions) { snapshot in
                    Button {
                        if let loaded = viewModel.loadAction(id: snapshot.actionID) {
                            editingAction = loaded
                        }
                    } label: {
                        ActionRowView(snapshot: snapshot)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    viewModel.deleteLocalActions(at: indexSet)
                }
                .onMove { source, destination in
                    viewModel.moveLocalActions(from: source, to: destination)
                }
            }
        }
    }

    @ViewBuilder
    private var scenesSection: some View {
        if !viewModel.scenes.isEmpty {
            Section {
                ForEach(viewModel.scenes) { scene in
                    SceneActionRowView(
                        scene: scene,
                        onToggle: { enabled in
                            viewModel.setSceneEnabled(scene.identifier, enabled: enabled)
                        },
                        onCustomize: {
                            if let first = viewModel.firstAction(forSceneId: scene.identifier) {
                                editingSceneAction = first
                            }
                        }
                    )
                }
            } header: {
                Text(L10n.SettingsDetails.Actions.Scenes.title)
            } footer: {
                Text(L10n.SettingsDetails.Actions.Scenes.footer)
            }
        }
    }

    @ViewBuilder
    private var serverActionsSection: some View {
        Section {
            if viewModel.serverActions.isEmpty {
                Text(L10n.SettingsDetails.Actions.ActionsSynced.empty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.serverActions) { snapshot in
                    Button {
                        if let loaded = viewModel.loadAction(id: snapshot.actionID) {
                            editingAction = loaded
                        }
                    } label: {
                        ActionRowView(snapshot: snapshot)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text(L10n.SettingsDetails.Actions.ActionsSynced.header)
        } footer: {
            if viewModel.serverActions.isEmpty {
                Text(L10n.SettingsDetails.Actions.ActionsSynced.footerNoActions)
            } else {
                Text(L10n.SettingsDetails.Actions.ActionsSynced.footer)
            }
        }
    }

    private var serverUpdateSection: some View {
        Section {
            Button {
                viewModel.refreshServerActions()
            } label: {
                HStack {
                    Text(L10n.SettingsDetails.Actions.ServerControlled.Update.title)
                    Spacer()
                    if viewModel.isRefreshing {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isRefreshing)
        }
    }

    /// Mirrors the legacy `ActionConfigurator` "Create Automation" path: server-controlled
    /// actions should never be persisted from this sheet (they're owned by the server),
    /// even though the same callback funnels both Save and Create-Automation actions.
    private func handleSheetSave(updated: Action, openAutomationEditor: Bool) {
        if openAutomationEditor, updated.isServerControlled {
            // Don't write back; just open the automation editor.
        } else {
            viewModel.save(action: updated)
        }
        if openAutomationEditor {
            openAutomationEditorIfAvailable(for: updated)
        }
    }

    private func openAutomationEditorIfAvailable(for action: Action) {
        Current.sceneManager.webViewWindowControllerPromise
            .then(\.webViewControllerPromise)
            .done { controller in
                controller.openActionAutomationEditor(actionId: action.ID)
            }.cauterize()
    }
}

// MARK: - Row views

private struct ActionRowView: View {
    let snapshot: ActionRowSnapshot

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Image(
                uiImage: MaterialDesignIcons(named: snapshot.iconName)
                    .image(ofSize: MaterialDesignIcons.settingsIconSize, color: .label)
            )
            .renderingMode(.template)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.name)
                    .foregroundStyle(.primary)
                Text(snapshot.text.isEmpty ? L10n.ActionsConfigurator.Rows.Text.title : snapshot.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemSymbol: .chevronRight)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct SceneActionRowView: View {
    let scene: ActionsSceneSnapshot
    let onToggle: (Bool) -> Void
    let onCustomize: () -> Void

    @State private var isEnabled: Bool

    init(scene: ActionsSceneSnapshot, onToggle: @escaping (Bool) -> Void, onCustomize: @escaping () -> Void) {
        self.scene = scene
        self.onToggle = onToggle
        self.onCustomize = onCustomize
        self._isEnabled = State(initialValue: scene.actionEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    isEnabled = newValue
                    onToggle(newValue)
                }
            )) {
                HStack(spacing: DesignSystem.Spaces.two) {
                    if let iconName = scene.icon {
                        let icon = MaterialDesignIcons(serversideValueNamed: iconName)
                        Image(uiImage: icon.image(
                            ofSize: MaterialDesignIcons.settingsIconSize,
                            color: .label
                        ))
                        .renderingMode(.template)
                    }
                    Text(scene.name ?? scene.identifier)
                }
            }
            if isEnabled {
                Button(L10n.SettingsDetails.Actions.Scenes.customizeAction) {
                    onCustomize()
                }
                .font(.footnote)
            }
        }
        // Keep local @State in sync with the upstream Realm-backed snapshot, otherwise
        // an external change to `actionEnabled` (sync, another screen, etc.) would not
        // update the toggle while the row is on screen.
        .onChange(of: scene.actionEnabled) { newValue in
            if newValue != isEnabled {
                isEnabled = newValue
            }
        }
    }
}

// MARK: - Sheet wrapper

private struct ActionEditorSheet: View {
    let action: Action
    let isNew: Bool
    let onSave: (Action, _ openAutomationEditor: Bool) -> Void

    var body: some View {
        NavigationView {
            ActionConfiguratorView(action: isNew ? nil : action) { updated, openAutomationEditor in
                onSave(updated, openAutomationEditor)
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Action Identifiable

extension Action: @retroactive Identifiable {
    public var id: String { ID }
}

#Preview {
    NavigationView {
        ActionsSettingsView()
    }
}
