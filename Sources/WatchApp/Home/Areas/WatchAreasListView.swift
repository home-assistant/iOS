import SFSafeSymbols
import Shared
import SwiftUI

/// One server's areas, pushed by the grouped areas row (directly, or through the server picker
/// when multiple servers have areas). Areas without watch-compatible entities are dropped, the
/// same rule the home screen applies. The navigation bar stays hidden — the custom header
/// provides the back button, matching `WatchFolderContentView`.
struct WatchAreasListView: View {
    let serverId: String
    @Environment(\.dismiss) private var dismiss
    @State private var areas: [AppArea] = []

    /// Serial queue for the area load — the fetches are synchronous database reads that would
    /// block the main thread.
    private static let loadQueue = DispatchQueue(label: "watch-areas-list", qos: .userInitiated)

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
            loadAreas()
        }
    }

    private func loadAreas() {
        let serverId = serverId
        Self.loadQueue.async {
            let populatedAreas = (try? AppArea.fetchWatchPopulatedAreas(for: serverId)) ?? []
            DispatchQueue.main.async {
                areas = populatedAreas
            }
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
