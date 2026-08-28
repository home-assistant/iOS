import SFSafeSymbols
import Shared
import SwiftUI

/// Picks one of a server's actions (`domain.service`) for a magic item's "perform action" behavior.
///
/// The list is the one the "Perform action" App Intent already offers in Shortcuts — it comes from
/// `AppIntentServerAPI`, so the actions carry the frontend's own names and descriptions.
struct ServerActionPicker: View {
    /// Returns the server the action belongs to, and the action's `domain.service` id.
    @Binding private var selectedServerId: String?
    @Binding private var selectedActionId: String?

    @State private var showList = false
    @State private var isLoading = false
    @State private var serverActions: [ServerActions] = []
    @State private var searchTerm = ""

    init(selectedServerId: Binding<String?>, selectedActionId: Binding<String?>) {
        self._selectedServerId = selectedServerId
        self._selectedActionId = selectedActionId
    }

    var body: some View {
        Button(action: {
            showList = true
        }, label: {
            if let selectedActionId {
                Text(verbatim: displayName(for: selectedActionId))
            } else {
                Text(verbatim: L10n.MagicItem.Action.PerformAction.Picker.placeholder)
            }
        })
        .sheet(isPresented: $showList) {
            NavigationView {
                list
            }
        }
    }

    private var list: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        HAProgressView()
                        Spacer()
                    }
                    .padding()
                }
            } else if serverActions.allSatisfy({ $0.actions.isEmpty }) {
                Section {
                    Text(verbatim: L10n.MagicItem.Action.PerformAction.Picker.empty)
                        .foregroundColor(.secondary)
                }
            }

            ForEach(serverActions) { server in
                Section(server.name) {
                    ForEach(filteredActions(for: server), id: \.actionId) { action in
                        row(server: server, action: action)
                    }
                }
            }
        }
        .searchable(text: $searchTerm)
        .onAppear {
            fetchActions()
        }
        .navigationViewStyle(.stack)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CloseButton {
                    showList = false
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    fetchActions(force: true)
                }, label: {
                    Image(systemSymbol: .arrowClockwise)
                })
            }
        }
    }

    private func row(server: ServerActions, action: IntentActionDefinition) -> some View {
        Button(action: {
            selectedServerId = server.id
            selectedActionId = action.actionId
            showList = false
        }, label: {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(verbatim: action.displayName)
                    Text(verbatim: action.actionId)
                        .font(DesignSystem.Font.footnote)
                        .foregroundStyle(.secondary)
                }
                if isSelected(server: server, action: action) {
                    Spacer()
                    Image(systemSymbol: .checkmark)
                }
            }
        })
        .tint(.accentColor)
    }

    private func isSelected(server: ServerActions, action: IntentActionDefinition) -> Bool {
        selectedServerId == server.id && selectedActionId == action.actionId
    }

    /// The name to show on the picker's own row. Until the servers answer there is nothing to look
    /// the id up in, so the stored `domain.service` stands in for it.
    private func displayName(for actionId: String) -> String {
        let definition = serverActions
            .first(where: { $0.id == selectedServerId })?
            .actions
            .first(where: { $0.actionId == actionId })
        return definition?.displayName ?? actionId
    }

    private func filteredActions(for server: ServerActions) -> [IntentActionDefinition] {
        guard searchTerm.count > 2 else { return server.actions }
        return server.actions.filter { action in
            action.displayName.localizedCaseInsensitiveContains(searchTerm)
                || action.actionId.localizedCaseInsensitiveContains(searchTerm)
        }
    }

    /// Loads every server's actions. Each server is asked on its own so one unreachable server
    /// leaves the others' actions listed instead of emptying the picker.
    private func fetchActions(force: Bool = false) {
        guard !isLoading, force || serverActions.isEmpty else { return }
        isLoading = true
        Task { @MainActor in
            var results: [ServerActions] = []
            for server in Current.servers.all.sorted(by: { $0.info.sortOrder < $1.info.sortOrder }) {
                do {
                    let definitions = try await AppIntentServerAPI.actionDefinitions(server: server)
                    results.append(.init(
                        id: server.identifier.rawValue,
                        name: server.info.name,
                        actions: definitions
                    ))
                } catch {
                    Current.Log.error(
                        "Failed to load actions for action picker, server: \(server.info.name), error: \(error)"
                    )
                }
            }
            serverActions = results
            isLoading = false
        }
    }

    private struct ServerActions: Identifiable {
        let id: String
        let name: String
        let actions: [IntentActionDefinition]
    }
}

#Preview {
    List {
        ServerActionPicker(
            selectedServerId: .constant("1"),
            selectedActionId: .constant("light.turn_on")
        )
    }
}
