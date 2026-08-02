import Foundation
import Shared

final class WatchAreaEntitiesViewModel: ObservableObject {
    /// An area entity rendered as a home-style row: the on-the-fly item plus its resolved info.
    struct Entry: Identifiable {
        let item: MagicItem
        let info: MagicItem.Info

        var id: String { item.serverUniqueId }
    }

    @Published private(set) var areaName: String?
    /// `nil` until the first load finishes (spinner); empty afterwards means the area has no
    /// watch-compatible entities.
    @Published private(set) var entries: [Entry]?

    let areaId: String
    let serverId: String

    /// Serial queue for the candidate build — `loadInformation` and the info lookups are synchronous
    /// database work that would freeze the UI on the main thread (same reasoning as the add flow's
    /// `availableItemsQueue`).
    private static let loadQueue = DispatchQueue(label: "watch-area-entities", qos: .userInitiated)
    private var isLoading = false

    init(areaId: String, serverId: String) {
        self.areaId = areaId
        self.serverId = serverId
    }

    func load() {
        // `onAppear` fires again when the user navigates back from a pushed controls screen;
        // a finished load is kept, matching the add flow.
        guard entries == nil, !isLoading else { return }
        isLoading = true
        let areaId = areaId
        let serverId = serverId
        Self.loadQueue.async { [weak self] in
            let area = (try? AppArea.fetchArea(areaId: areaId, serverId: serverId)) ?? nil
            let provider = Current.magicItemProvider()
            provider.loadInformation { entitiesPerServer in
                let allowedDomains = Set(Domain.watchAddable.map(\.rawValue))
                let entries: [Entry] = (entitiesPerServer[serverId] ?? [])
                    .filter { entity in
                        area?.entities.contains(entity.entityId) == true
                            && allowedDomains.contains(entity.domain)
                            && entity.entityCategory == nil
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    .compactMap { entity in
                        let item = MagicItem(id: entity.entityId, serverId: serverId, type: .entity)
                        guard let info = provider.getInfo(for: item) else { return nil }
                        return Entry(item: item, info: info)
                    }
                DispatchQueue.main.async { [weak self] in
                    self?.areaName = area?.name
                    self?.entries = entries
                    self?.isLoading = false
                }
            }
        }
    }
}
