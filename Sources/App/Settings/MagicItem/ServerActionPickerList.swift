import SFSafeSymbols
import Shared
import SwiftUI

/// The sheet `ServerActionPicker` presents: the actions one server offers, searchable, with the
/// chosen one ticked.
///
/// It keeps no state of its own — the picker owns the loading and the selection — so it renders the
/// same way from a fixed list of actions as it does from a live server.
struct ServerActionPickerList: View {
    let actions: [IntentActionDefinition]
    let isLoading: Bool
    @Binding var searchTerm: String
    let selectedActionId: String?
    let onSelect: (IntentActionDefinition) -> Void
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
            } else if actions.isEmpty {
                Section {
                    Text(verbatim: L10n.MagicItem.Action.PerformAction.Picker.empty)
                        .foregroundStyle(Color.secondary)
                }
            }

            ForEach(filteredActions, id: \.actionId) { action in
                Button {
                    onSelect(action)
                } label: {
                    ServerActionRowView(action: action, isSelected: action.actionId == selectedActionId)
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

    /// Searching matches the friendly name and the `domain.service` pair alike, so a user who knows
    /// the action's id finds it as easily as one reading the translated names.
    private var filteredActions: [IntentActionDefinition] {
        guard searchTerm.count > 2 else { return actions }
        return actions.filter { action in
            action.displayName.localizedCaseInsensitiveContains(searchTerm)
                || action.actionId.localizedCaseInsensitiveContains(searchTerm)
        }
    }
}

#Preview {
    NavigationView {
        ServerActionPickerList(
            actions: [
                .init(domain: "light", service: "turn_on", name: "Turn on", actionDescription: nil),
                .init(domain: "light", service: "toggle", name: "Toggle", actionDescription: nil),
            ],
            isLoading: false,
            searchTerm: .constant(""),
            selectedActionId: "light.turn_on",
            onSelect: { _ in },
            onReload: {},
            onClose: {}
        )
    }
}
