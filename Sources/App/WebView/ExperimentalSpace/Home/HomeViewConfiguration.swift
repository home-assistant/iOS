import Foundation
import GRDB
import Shared

struct HomeViewConfiguration: Codable, FetchableRecord, PersistableRecord, Equatable {
    /// Server identifier (primary key)
    let id: String
    var sectionOrder: [String]
    var visibleSectionIds: Set<String>
    var allowMultipleSelection: Bool
    var entityOrderByRoom: [String: [String]]
    var hiddenEntityIds: Set<String>
    var selectedBackgroundId: String?

    init(
        id: String,
        sectionOrder: [String] = [],
        visibleSectionIds: Set<String> = [],
        allowMultipleSelection: Bool = false,
        entityOrderByRoom: [String: [String]] = [:],
        hiddenEntityIds: Set<String> = [],
        selectedBackgroundId: String? = nil
    ) {
        self.id = id
        self.sectionOrder = sectionOrder
        self.visibleSectionIds = visibleSectionIds
        self.allowMultipleSelection = allowMultipleSelection
        self.entityOrderByRoom = entityOrderByRoom
        self.hiddenEntityIds = hiddenEntityIds
        self.selectedBackgroundId = selectedBackgroundId
    }

    /// Fetch configuration for a specific server
    static func configuration(for serverId: String) throws -> HomeViewConfiguration? {
        try Current.database().read { db in
            try HomeViewConfiguration.fetchOne(db, key: serverId)
        }
    }

    /// Save or update cache for a specific server
    func save() throws {
        try Current.database().write { db in
            try save(db)
        }
    }

    /// Delete cache for a specific server
    func delete() throws {
        try Current.database().write { db in
            _ = try HomeViewConfiguration.deleteOne(db, key: id)
        }
    }
}
