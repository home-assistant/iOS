import Shared
import SwiftUI

/// The list of addable entities for a single server. Rows mirror the iOS entity picker: icon, name,
/// and the `Area • Device` context underneath. Tapping pushes the name/icon editor.
struct WatchConfigAddEntityListView: View {
    let group: WatchConfigAvailableItems.ServerGroup
    /// When set, only entities in this area are listed ("All areas" passes nil).
    let areaFilter: String?
    let viewModel: WatchHomeViewModel
    let folderId: String?
    let finish: () -> Void

    @State private var searchTerm = ""
    @State private var selectedDomain: Domain?

    var body: some View {
        List {
            TextField(L10n.Watch.Config.Add.searchPlaceholder, text: $searchTerm)
            if availableDomains.count > 1 {
                domainFilter
                    .listRowBackground(Color.clear)
            }
            ForEach(filteredCandidates, id: \.item.serverUniqueId) { candidate in
                NavigationLink {
                    WatchConfigItemEditView(
                        mode: .add,
                        placeholderName: candidate.info.name,
                        item: candidate.item,
                        info: candidate.info
                    ) { edited in
                        add(edited, info: candidate.info)
                    }
                } label: {
                    WatchConfigItemRow(
                        item: candidate.item,
                        itemInfo: candidate.info,
                        subtitle: candidate.contextSubtitle
                    )
                }
                .watchHomeItemRowStyle(tint: nil)
            }
        }
        .navigationTitle(Text(verbatim: areaFilter ?? group.serverName))
    }

    private var domainFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spaces.half) {
                WatchDomainFilterPill(title: L10n.Watch.Config.Add.Filter.all, selected: selectedDomain == nil) {
                    selectedDomain = nil
                }
                ForEach(availableDomains, id: \.rawValue) { domain in
                    WatchDomainFilterPill(title: domain.name, selected: selectedDomain == domain) {
                        selectedDomain = selectedDomain == domain ? nil : domain
                    }
                }
            }
        }
    }

    private var candidatesInArea: [WatchConfigAvailableItems.Candidate] {
        guard let areaFilter else { return group.candidates }
        return group.candidates.filter { $0.areaName == areaFilter }
    }

    /// The addable domains present in this area's candidates, in the watch's canonical order.
    private var availableDomains: [Domain] {
        let present = Set(candidatesInArea.compactMap { Domain(entityId: $0.item.id) })
        return Domain.watchAddable.filter(present.contains)
    }

    private var filteredCandidates: [WatchConfigAvailableItems.Candidate] {
        var candidates = candidatesInArea
        if let selectedDomain {
            candidates = candidates.filter { Domain(entityId: $0.item.id) == selectedDomain }
        }
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return candidates }
        return candidates.filter { $0.item.name(info: $0.info).lowercased().contains(term) }
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
        WatchConfigAddEntityListView(
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
            areaFilter: nil,
            viewModel: WatchHomeViewModel(),
            folderId: nil,
            finish: {}
        )
    }
}
