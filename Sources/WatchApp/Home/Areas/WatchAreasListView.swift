import SFSafeSymbols
import Shared
import SwiftUI

/// One server's areas, pushed by the grouped areas row (directly, or through the server picker
/// when multiple servers have areas). The navigation bar stays hidden — the custom header provides
/// the back button, matching `WatchFolderContentView`.
struct WatchAreasListView: View {
    let serverId: String
    @Environment(\.dismiss) private var dismiss
    @State private var areas: [AppArea] = []

    var body: some View {
        List {
            header
            ForEach(areas, id: \.id) { area in
                WatchAreaRow(area: area)
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
        .onAppear {
            areas = (try? AppArea.fetchAreas(for: serverId)) ?? []
        }
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
            Text(verbatim: title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
    }

    /// The server name only helps when the config spans multiple servers; otherwise "Areas".
    private var title: String {
        guard Current.servers.all.count > 1,
              let server = Current.servers.server(forServerIdentifier: serverId) else {
            return L10n.Watch.Home.Areas.title
        }
        return server.info.name
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationStack {
        WatchAreasListView(serverId: "1")
    }
}
