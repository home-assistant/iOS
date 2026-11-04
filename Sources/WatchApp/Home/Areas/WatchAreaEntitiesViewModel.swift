import Foundation
import Shared

final class WatchAreaEntitiesViewModel: ObservableObject {
    @Published private(set) var areaName: String?
    /// `nil` until the first load finishes (spinner); empty afterwards means the area has no
    /// watch-compatible entities.
    @Published private(set) var sections: WatchEntitySections?

    let areaId: String
    let serverId: String

    /// Serial queue for the candidate build — `WatchEntitySections.make` is synchronous database
    /// work that would freeze the UI on the main thread (same reasoning as the add flow's
    /// `availableItemsQueue`).
    private static let loadQueue = DispatchQueue(label: "watch-area-entities", qos: .userInitiated)
    private var isLoading = false

    init(areaId: String, serverId: String) {
        self.areaId = areaId
        self.serverId = serverId
    }

    func load() {
        // `onAppear` fires again when the user navigates back from a pushed controls or device
        // screen; a finished load is kept, matching the add flow.
        guard sections == nil, !isLoading else { return }
        isLoading = true
        let areaId = areaId
        let serverId = serverId
        Self.loadQueue.async { [weak self] in
            guard let area = try? AppArea.fetchArea(areaId: areaId, serverId: serverId) else {
                DispatchQueue.main.async { [weak self] in
                    self?.sections = .empty
                    self?.isLoading = false
                }
                return
            }
            WatchEntitySections.make(
                serverId: serverId,
                isIncluded: { entity, _ in area.entities.contains(entity.entityId) }
            ) { sections in
                DispatchQueue.main.async { [weak self] in
                    self?.areaName = area.name
                    self?.sections = sections
                    self?.isLoading = false
                }
            }
        }
    }
}
