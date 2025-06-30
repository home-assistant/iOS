import Shared
import SwiftUI

struct ServerPickerView: View {
    private let preSelectedServer: Server?

    /// The selected server id.
    @State private var selection: String? = nil

    /// Initializes with server to pre-select it.
    init(server: Server? = nil) {
        self.preSelectedServer = server
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
            guard selection == nil else { return }
            selection = preSelectedServer?.identifier.rawValue ?? Current.servers.all.first?.identifier.rawValue
        }
        .onChange(of: selection) { newValue in
            Current.sceneManager.webViewWindowControllerPromise.done { windowController in
                guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == newValue }) else {
                    Current.Log
                        .error(
                            "Failed to find server with id: \(newValue ?? "nil") so server picker view could open server"
                        )
                    return
                }

                windowController.open(server: server)
            }
        }
    }
}

#Preview {
    ServerPickerView()
}
