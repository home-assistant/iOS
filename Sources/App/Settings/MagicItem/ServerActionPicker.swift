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
    @State private var groups: [ServerActionGroup] = []
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
        // A saved item arrives with nothing but the action's id, and the name lives on the server,
        // so the servers are asked as soon as the row appears rather than only when the sheet opens.
        .onAppear {
            guard selectedActionId != nil else { return }
            fetchActions()
        }
        .sheet(isPresented: $showList) {
            NavigationView {
                ServerActionPickerList(
                    groups: groups,
                    isLoading: isLoading,
                    searchTerm: $searchTerm,
                    selectedServerId: selectedServerId,
                    selectedActionId: selectedActionId,
                    onSelect: { group, action in
                        selectedServerId = group.id
                        selectedActionId = action.actionId
                        showList = false
                    },
                    onReload: {
                        fetchActions(force: true)
                    },
                    onClose: {
                        showList = false
                    }
                )
                .onAppear {
                    fetchActions()
                }
            }
        }
    }

    /// The name to show on the picker's own row — never the `domain.service` pair, which means
    /// nothing to most people.
    ///
    /// Until the servers answer there is nothing to look the id up in, so the id is read the way
    /// the server itself would name an action it has no translation for: its service, spelled out.
    private func displayName(for actionId: String) -> String {
        let definition = groups
            .first(where: { $0.id == selectedServerId })?
            .actions
            .first(where: { $0.actionId == actionId })
        return definition?.displayName ?? Self.derivedName(from: actionId)
    }

    /// `light.turn_on` reads as "Turn on", matching what `IntentActionDefinition` falls back to
    /// when the server offers no name of its own.
    private static func derivedName(from actionId: String) -> String {
        let service = actionId.split(separator: ".", maxSplits: 1).last.map { String($0) } ?? actionId
        return service.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }

    /// Loads every server's actions. Each server is asked on its own so one unreachable server
    /// leaves the others' actions listed instead of emptying the picker.
    private func fetchActions(force: Bool = false) {
        guard !isLoading, force || groups.isEmpty else { return }
        isLoading = true
        Task { @MainActor in
            var results: [ServerActionGroup] = []
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
            groups = results
            isLoading = false
        }
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
