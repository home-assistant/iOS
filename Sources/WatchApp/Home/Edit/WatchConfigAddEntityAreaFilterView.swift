import Shared
import SwiftUI

/// Area layer of the entity add flow: pick an area — or "All areas" — before the entity list, so
/// long entity lists stay navigable on the small screen. This only narrows which entities are
/// listed; adding an area itself as an item is `WatchConfigAddAreaListView`.
struct WatchConfigAddEntityAreaFilterView: View {
    let group: WatchConfigAvailableItems.ServerGroup
    let viewModel: WatchHomeViewModel
    let folderId: String?
    let finish: () -> Void

    var body: some View {
        List {
            areaRow(title: L10n.EntityPicker.Filter.Area.All.title, areaFilter: nil)
            ForEach(areas, id: \.self) { area in
                areaRow(title: area, areaFilter: area)
            }
        }
        .navigationTitle(Text(verbatim: group.serverName))
    }

    private func areaRow(title: String, areaFilter: String?) -> some View {
        NavigationLink {
            WatchConfigAddEntityListView(
                group: group,
                areaFilter: areaFilter,
                viewModel: viewModel,
                folderId: folderId,
                finish: finish
            )
        } label: {
            Text(verbatim: title)
        }
    }

    private var areas: [String] {
        Array(Set(group.candidates.compactMap(\.areaName))).sorted()
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationView {
        WatchConfigAddEntityAreaFilterView(
            group: .init(
                serverId: "1",
                serverName: "Home",
                candidates: [
                    .init(
                        item: .init(id: "light.kitchen", serverId: "1", type: .entity),
                        info: .init(id: "1-light.kitchen", name: "Kitchen Light", iconName: "mdi:ceiling-light"),
                        contextSubtitle: "Kitchen",
                        areaName: "Kitchen"
                    ),
                ]
            ),
            viewModel: WatchHomeViewModel(),
            folderId: nil,
            finish: {}
        )
    }
}
