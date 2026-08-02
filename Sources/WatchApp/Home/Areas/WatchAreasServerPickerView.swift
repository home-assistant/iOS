import SFSafeSymbols
import Shared
import SwiftUI

/// The server chooser of the grouped areas row, shown only when more than one server has areas
/// with watch-compatible entities — the ids come from `WatchHomeAreasMode.grouped(serverIds:)`,
/// so servers whose areas the home screen dropped never appear here. Each row pushes that
/// server's area list through the home stack's `watchNavigate` action.
struct WatchAreasServerPickerView: View {
    let serverIds: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.watchNavigate) private var navigate

    var body: some View {
        List {
            header
            ForEach(servers, id: \.identifier.rawValue) { server in
                Button {
                    navigate(.areasList(serverId: server.identifier.rawValue))
                } label: {
                    HStack {
                        Text(verbatim: server.info.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemSymbol: .chevronRight)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .watchItemRowStyle()
            }
        }
        .ignoresSafeArea([.all], edges: .top)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .modify { view in
            if #available(watchOS 11.0, *) {
                view.toolbarVisibility(.hidden, for: .navigationBar)
            } else {
                view.toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    private var servers: [Server] {
        serverIds.compactMap { Current.servers.server(forServerIdentifier: $0) }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemSymbol: .chevronLeft)
            }
            .buttonStyle(.plain)
            .circularGlassOrLegacyBackground()
            Text(verbatim: L10n.Watch.Home.Areas.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationStack {
        WatchAreasServerPickerView(serverIds: ["1", "2"])
    }
}
