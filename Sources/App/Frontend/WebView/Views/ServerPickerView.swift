import Shared
import SwiftUI

struct ServerPickerView: View {
    private let preSelectedServer: Server?
    private let onSelect: ((Server) -> Void)?

    /// The selected server id.
    @State private var selection: String
    @State private var isSynchronizingSelection = false

    /// Initializes with server to pre-select it.
    init(server: Server? = nil, onSelect: ((Server) -> Void)? = nil) {
        self.preSelectedServer = server
        self.onSelect = onSelect
        self
            ._selection = State(
                initialValue: server?.identifier.rawValue ?? Current.servers.all.first?.identifier
                    .rawValue ?? ""
            )
    }

    var body: some View {
        Picker(selection: $selection) {
            ForEach(Current.servers.all, id: \.identifier) { server in
                Text(server.info.name)
                    .tag(server.identifier.rawValue)
            }
        } label: {
            Text(L10n.ServersSelection.title)
        }
        .pickerStyle(.menu)
        .frame(minWidth: 100)
        .onAppear {
            synchronizeSelectionIfNeeded()
        }
        .onChange(of: preSelectedServer?.identifier.rawValue) { _ in
            synchronizeSelectionIfNeeded()
        }
        .onChange(of: selection) { newValue in
            guard !isSynchronizingSelection else { return }

            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == newValue }) else {
                Current.Log
                    .error(
                        "Failed to find server with id: \(newValue) so server picker view could open server"
                    )
                return
            }

            if let onSelect {
                onSelect(server)
            } else {
                Current.sceneManager.webViewWindowControllerPromise.done { windowController in
                    windowController.open(server: server)
                }
            }
        }
    }

    private func synchronizeSelectionIfNeeded() {
        let validServerIDs = Set(Current.servers.all.map(\.identifier.rawValue))
        let preferredSelection = preSelectedServer?.identifier.rawValue
            ?? Current.servers.all.first?.identifier.rawValue
            ?? ""

        let targetSelection = validServerIDs.contains(selection) ? selection : preferredSelection

        guard selection != targetSelection else { return }

        isSynchronizingSelection = true
        selection = targetSelection

        DispatchQueue.main.async {
            isSynchronizingSelection = false
        }
    }
}

#Preview {
    ServerPickerView()
}
