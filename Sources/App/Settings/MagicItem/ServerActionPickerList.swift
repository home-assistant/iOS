import SFSafeSymbols
import Shared
import SwiftUI

/// The sheet `ServerActionPicker` presents: each server's actions, searchable, with the chosen one
/// ticked.
///
/// It keeps no state of its own — the picker owns the loading and the selection — so it renders the
/// same way from a fixed list of actions as it does from a live server.
struct ServerActionPickerList: View {
    let groups: [ServerActionGroup]
    let isLoading: Bool
    @Binding var searchTerm: String
    let selectedServerId: String?
    let selectedActionId: String?
    let onSelect: (ServerActionGroup, IntentActionDefinition) -> Void
    let onReload: () -> Void
    let onClose: () -> Void

    var body: some View {
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
            } else if groups.allSatisfy(\.actions.isEmpty) {
                Section {
                    Text(verbatim: L10n.MagicItem.Action.PerformAction.Picker.empty)
                        .foregroundColor(.secondary)
                }
            }

            ForEach(groups) { group in
                Section(group.name) {
                    ForEach(filteredActions(in: group), id: \.actionId) { action in
                        row(group: group, action: action)
                    }
                }
            }
        }
        .searchable(text: $searchTerm)
        .navigationViewStyle(.stack)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CloseButton {
                    onClose()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    onReload()
                }, label: {
                    Image(systemSymbol: .arrowClockwise)
                })
            }
        }
    }

    private func row(group: ServerActionGroup, action: IntentActionDefinition) -> some View {
        Button(action: {
            onSelect(group, action)
        }, label: {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(verbatim: action.displayName)
                    // The `domain.service` pair is what actually gets stored and called, so it stays
                    // visible next to the friendly name the frontend supplies.
                    Text(verbatim: action.actionId)
                        .font(DesignSystem.Font.footnote)
                        .foregroundStyle(.secondary)
                }
                if isSelected(group: group, action: action) {
                    Spacer()
                    Image(systemSymbol: .checkmark)
                }
            }
        })
        .tint(.accentColor)
    }

    private func isSelected(group: ServerActionGroup, action: IntentActionDefinition) -> Bool {
        selectedServerId == group.id && selectedActionId == action.actionId
    }

    /// Searching matches both the friendly name and the `domain.service` pair, so a user who knows
    /// the action's id finds it as easily as one reading the translated names.
    private func filteredActions(in group: ServerActionGroup) -> [IntentActionDefinition] {
        guard searchTerm.count > 2 else { return group.actions }
        return group.actions.filter { action in
            action.displayName.localizedCaseInsensitiveContains(searchTerm)
                || action.actionId.localizedCaseInsensitiveContains(searchTerm)
        }
    }
}

#Preview {
    NavigationView {
        ServerActionPickerList(
            groups: [
                .init(
                    id: "1",
                    name: "Home",
                    actions: [
                        .init(domain: "light", service: "turn_on", name: "Turn on", actionDescription: nil),
                        .init(domain: "light", service: "toggle", name: "Toggle", actionDescription: nil),
                    ]
                ),
            ],
            isLoading: false,
            searchTerm: .constant(""),
            selectedServerId: "1",
            selectedActionId: "light.turn_on",
            onSelect: { _, _ in },
            onReload: {},
            onClose: {}
        )
    }
}
