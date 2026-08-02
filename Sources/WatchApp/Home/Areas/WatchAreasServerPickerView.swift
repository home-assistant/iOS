import Shared
import SwiftUI

/// The server chooser of the grouped areas row, shown only when more than one server has areas
/// with watch-compatible entities — the ids come from `WatchHomeAreasMode.grouped(serverIds:)`,
/// so servers whose areas the home screen dropped never appear here. Plain rows and a system
/// navigation title, matching the entity picker (add) flow's server list. Each row pushes that
/// server's area list through the home stack's `watchNavigate` action.
struct WatchAreasServerPickerView: View {
    let serverIds: [String]
    @Environment(\.watchNavigate) private var navigate

    var body: some View {
        List {
            ForEach(servers, id: \.identifier.rawValue) { server in
                Button {
                    navigate(.areasList(serverId: server.identifier.rawValue))
                } label: {
                    Text(verbatim: server.info.name)
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Config.Assist.selectServer))
    }

    private var servers: [Server] {
        serverIds.compactMap { Current.servers.server(forServerIdentifier: $0) }
    }
}

#Preview {
    NavigationStack {
        WatchAreasServerPickerView(serverIds: ["1", "2"])
    }
}
