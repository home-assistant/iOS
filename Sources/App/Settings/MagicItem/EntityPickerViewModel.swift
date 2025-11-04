import Foundation
import Shared

final class EntityPickerViewModel: ObservableObject {
    @Published var entities: [HAAppEntity] = []
    @Published var showList = false
    @Published var searchTerm = ""
    @Published var selectedServerId: String?

    let domainFilter: Domain?

    init(domainFilter: Domain?) {
        self.domainFilter = domainFilter
    }

    func fetchEntities() {
        do {
            var newEntities = try HAAppEntity.config() ?? []
            if let domainFilter {
                newEntities = newEntities.filter({ entity in
                    entity.domain == domainFilter.rawValue
                })
            }
            entities = newEntities
        } catch {
            Current.Log.error("Failed to fetch entities for entity picker, error: \(error)")
        }
    }
}
