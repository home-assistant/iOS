import Shared
import SwiftUI

/// Picks one of a server's actions (`domain.service`) for a magic item's "perform action" behavior.
///
/// Only the item's own server is offered: the action runs against the same server the item's entity
/// belongs to, so another server's actions could never apply. The list is the one the "Perform
/// action" App Intent already offers in Shortcuts — it comes from `AppIntentServerAPI`, so the
/// actions carry the frontend's own names, icons and descriptions.
struct ServerActionPicker: View {
    /// The server the item belongs to, and so the only one whose actions can run.
    let serverId: String
    @Binding private var selectedActionId: String?

    @State private var showList = false
    @State private var isLoading = false
    @State private var actions: [IntentActionDefinition] = []
    @State private var searchTerm = ""

    init(serverId: String, selectedActionId: Binding<String?>) {
        self.serverId = serverId
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
        // so the server is asked as soon as the row appears rather than only when the sheet opens.
        .onAppear {
            guard selectedActionId != nil else { return }
            fetchActions()
        }
        .sheet(isPresented: $showList) {
            NavigationView {
                ServerActionPickerList(
                    actions: actions,
                    isLoading: isLoading,
                    searchTerm: $searchTerm,
                    selectedActionId: selectedActionId,
                    onSelect: { action in
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
    /// Until the server answers there is nothing to look the id up in, so the id is read the way
    /// the server itself would name an action it has no translation for: its service, spelled out.
    private func displayName(for actionId: String) -> String {
        let definition = actions.first(where: { $0.actionId == actionId })
        return definition?.displayName ?? Self.derivedName(from: actionId)
    }

    /// `light.turn_on` reads as "Turn on", matching what `IntentActionDefinition` falls back to
    /// when the server offers no name of its own.
    private static func derivedName(from actionId: String) -> String {
        let service = actionId.split(separator: ".", maxSplits: 1).last.map { String($0) } ?? actionId
        return service.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }

    private func fetchActions(force: Bool = false) {
        guard !isLoading, force || actions.isEmpty else { return }
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            Current.Log.error("No server \(serverId) available for the action picker")
            return
        }
        isLoading = true
        Task { @MainActor in
            do {
                actions = try await AppIntentServerAPI.actionDefinitions(server: server)
            } catch {
                Current.Log.error(
                    "Failed to load actions for action picker, server: \(server.info.name), error: \(error)"
                )
            }
            isLoading = false
        }
    }
}

#Preview {
    List {
        ServerActionPicker(
            serverId: "1",
            selectedActionId: .constant("light.turn_on")
        )
    }
}
