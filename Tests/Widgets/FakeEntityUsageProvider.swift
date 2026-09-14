import Foundation
import Shared

/// Stands in for the cached ranking of the entities this user controls most, and records which
/// servers were asked about so a test can tell "showed the picks" from "fell back to the ranking".
final class FakeEntityUsageProvider: EntityUsageProviderProtocol {
    private let mostUsed: [String]
    private(set) var askedForServerIds: [String] = []

    init(mostUsed: [String]) {
        self.mostUsed = mostUsed
    }

    func refresh(for server: Server, now: Date) async -> [String] {
        mostUsedEntityIds(serverId: server.identifier.rawValue, limit: nil)
    }

    func mostUsedEntityIds(serverId: String, limit: Int?) -> [String] {
        askedForServerIds.append(serverId)
        guard let limit else { return mostUsed }
        return Array(mostUsed.prefix(limit))
    }
}
