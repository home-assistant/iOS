import Foundation
import GRDB

public struct TrustedURLAllowlistRecord: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static let databaseTableName = GRDBDatabaseTable.trustedURLAllowlist.rawValue

    public let id: String
    public let serverId: String
    public let url: String

    public init(serverId: String, url: String) {
        self.serverId = serverId
        self.url = url
        self.id = Self.recordId(serverId: serverId, url: url)
    }

    public static func isAllowed(url: URL, serverIds: [String], database: DatabaseQueue = .appDatabase) -> Bool {
        let uniqueServerIds = Array(Set(serverIds)).sorted()
        guard !uniqueServerIds.isEmpty else {
            return false
        }

        return (try? database.read { db in
            let records = try TrustedURLAllowlistRecord
                .filter(Column(DatabaseTables.TrustedURLAllowlist.url.rawValue) == url.absoluteString)
                .filter(uniqueServerIds.contains(Column(DatabaseTables.TrustedURLAllowlist.serverId.rawValue)))
                .fetchAll(db)

            let allowedServerIds = Set(records.map(\.serverId))
            return allowedServerIds.count == uniqueServerIds.count
        }) ?? false
    }

    public static func allow(url: URL, serverIds: [String], database: DatabaseQueue = .appDatabase) throws {
        let uniqueServerIds = Array(Set(serverIds)).sorted()

        try database.write { db in
            for serverId in uniqueServerIds {
                try TrustedURLAllowlistRecord(serverId: serverId, url: url.absoluteString).save(db)
            }
        }
    }

    private static func recordId(serverId: String, url: String) -> String {
        "\(serverId)|\(url)"
    }
}
