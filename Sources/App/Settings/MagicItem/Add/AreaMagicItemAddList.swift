import SFSafeSymbols
import Shared
import SwiftUI

/// Picker for adding an area entry to the watch configuration: one section per server, listing the
/// areas that hold at least one watch-compatible entity. Tapping adds the area straight away (like
/// the Assist pipeline list) — the resulting item can then be renamed / recolored from the
/// configuration screen.
struct AreaMagicItemAddList: View {
    /// `nil` until the first load finishes, which is what puts the spinner on screen.
    @State private var groups: [WatchAddableAreaGroup]?
    @State private var isFetching = false
    @State private var searchTerm = ""

    let itemToAdd: (MagicItem) -> Void

    /// Serial queue the area resolution runs on — it reads the areas and entities of every server.
    private static let loadQueue = DispatchQueue(label: "area-magic-item-add-list", qos: .userInitiated)

    var body: some View {
        List {
            if let groups {
                if groups.isEmpty {
                    Section {
                        Text(L10n.MagicItem.ItemType.Area.List.empty)
                            .foregroundColor(.secondary)
                    }
                }
                ForEach(groups) { group in
                    Section(group.serverName) {
                        ForEach(filteredAreas(in: group), id: \.id) { area in
                            areaButton(area, serverId: group.serverId)
                        }
                    }
                }
            } else {
                Section {
                    HStack {
                        Spacer()
                        HAProgressView()
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .searchable(text: $searchTerm)
        .onAppear(perform: load)
    }

    private func areaButton(_ area: AppArea, serverId: String) -> some View {
        Button {
            itemToAdd(.init(id: area.areaId, serverId: serverId, type: .area))
        } label: {
            HStack {
                Image(uiImage: icon(for: area).image(
                    ofSize: .init(width: 18, height: 18),
                    color: .accent
                ))
                VStack(alignment: .leading, spacing: 2) {
                    Text(area.name)
                    if let floorName = area.floorName, !floorName.isEmpty {
                        Text(floorName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemSymbol: .plusCircleFill)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .tint(Color(uiColor: .label))
    }

    private func icon(for area: AppArea) -> MaterialDesignIcons {
        guard let iconName = area.icon else { return .textureBoxIcon }
        return MaterialDesignIcons(serversideValueNamed: iconName, fallback: .textureBoxIcon)
    }

    private func filteredAreas(in group: WatchAddableAreaGroup) -> [AppArea] {
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return group.areas }
        return group.areas.filter { $0.name.lowercased().contains(term) }
    }

    /// Resolving the areas reads every entity of every server, so it runs off the main thread — the
    /// list shows a spinner until it lands. A finished (or in-flight) load is kept: `onAppear` fires
    /// again every time the user switches back to this tab of the picker.
    private func load() {
        guard groups == nil, !isFetching else { return }
        isFetching = true
        // Servers are read here (main thread) so the background work only touches the database.
        let servers = Current.servers.all
        Self.loadQueue.async {
            let resolved = WatchAddableAreaGroup.make(servers: servers)
            DispatchQueue.main.async {
                groups = resolved
                isFetching = false
            }
        }
    }
}

#Preview {
    AreaMagicItemAddList { _ in
    }
}
