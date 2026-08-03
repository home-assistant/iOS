import Shared
import SwiftUI

/// The addable areas of a single server. Rows render the area exactly as the home screen will
/// (icon + name); tapping pushes the name/icon editor, matching the entity flow.
struct WatchConfigAddAreaListView: View {
    let group: WatchAddableAreaGroup
    let viewModel: WatchHomeViewModel
    let folderId: String?
    let finish: () -> Void

    @State private var searchTerm = ""

    var body: some View {
        List {
            TextField(L10n.Watch.Config.Add.searchPlaceholder, text: $searchTerm)
            ForEach(filteredAreas, id: \.id) { area in
                NavigationLink {
                    WatchConfigItemEditView(
                        mode: .add,
                        placeholderName: area.name,
                        item: item(for: area),
                        info: info(for: area)
                    ) { edited in
                        add(edited, info: info(for: area))
                    }
                } label: {
                    WatchConfigItemRow(item: item(for: area), itemInfo: info(for: area))
                }
                .watchHomeItemRowStyle(tint: nil)
            }
        }
        .navigationTitle(Text(verbatim: group.serverName))
    }

    private var filteredAreas: [AppArea] {
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return group.areas }
        return group.areas.filter { $0.name.lowercased().contains(term) }
    }

    private func item(for area: AppArea) -> MagicItem {
        MagicItem(id: area.areaId, serverId: group.serverId, type: .area)
    }

    /// Resolved here rather than through `MagicItemProvider`: the areas were just read from the
    /// database, so there is nothing left to look up.
    private func info(for area: AppArea) -> MagicItem.Info {
        .init(
            id: area.id,
            name: area.name,
            iconName: area.icon ?? MaterialDesignIcons.textureBoxIcon.name
        )
    }

    private func add(_ item: MagicItem, info: MagicItem.Info) {
        if let folderId {
            viewModel.addItemToFolder(folderId: folderId, item: item, info: info)
        } else {
            viewModel.addItem(item, info: info)
        }
        viewModel.saveConfig()
        finish()
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationView {
        WatchConfigAddAreaListView(
            group: .init(
                serverId: "1",
                serverName: "Home",
                areas: [
                    .init(
                        id: "1-living_room",
                        serverId: "1",
                        areaId: "living_room",
                        name: "Living Room",
                        aliases: [],
                        picture: nil,
                        icon: "mdi:sofa",
                        sortOrder: nil,
                        entities: ["light.living_room"]
                    ),
                ]
            ),
            viewModel: WatchHomeViewModel(),
            folderId: nil,
            finish: {}
        )
    }
}
