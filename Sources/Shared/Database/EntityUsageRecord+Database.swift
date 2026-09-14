import Foundation
import GRDB

// `EntityUsageRecord` itself lives in the `HAModels` package; these are its `Current.database()`-backed
// queries.
//
// Reads never throw: every caller is a widget timeline, an entity picker or a suggestion list, and
// each of them has something reasonable to show without this cache. A failure is logged and read as
// "nothing cached yet".
public extension EntityUsageRecord {
    /// Replaces a server's ranking for one time-of-day bucket.
    ///
    /// The whole bucket is rewritten rather than merged: the backend's response *is* the ranking
    /// for that bucket, so an entity missing from it is an entity the user stopped reaching for,
    /// and keeping the old row would pin it near the top forever.
    static func save(
        entityIds: [String],
        serverId: String,
        timeCategory: EntityUsageTimeCategory,
        now: Date = Date()
    ) {
        do {
            try Current.database().write { db in
                try EntityUsageRecord
                    .filter(Column(DatabaseTables.EntityUsageRecord.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.EntityUsageRecord.timeCategory.rawValue) == timeCategory.rawValue)
                    .deleteAll(db)

                for (rank, entityId) in entityIds.enumerated() {
                    try EntityUsageRecord(
                        serverId: serverId,
                        entityId: entityId,
                        timeCategory: timeCategory,
                        rank: rank,
                        updatedAt: now
                    ).insert(db)
                }
            }
        } catch {
            Current.Log.error("Failed to save entity usage for server \(serverId), error: \(error)")
        }
    }

    /// Every bucket stored for a server, stale rows included — `rankedEntityIds` is what drops those.
    static func all(serverId: String) -> [EntityUsageRecord] {
        do {
            return try Current.database().read { db in
                try EntityUsageRecord
                    .filter(Column(DatabaseTables.EntityUsageRecord.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to fetch entity usage for server \(serverId), error: \(error)")
            return []
        }
    }

    /// A server's most-controlled entity ids, most used first.
    ///
    /// `currentCategory` leads the list with the bucket for that time of day; pass `nil` for the
    /// merged order alone. See `rankedEntityIds(records:currentCategory:limit:now:)`.
    static func rankedEntityIds(
        serverId: String,
        currentCategory: EntityUsageTimeCategory? = nil,
        limit: Int? = nil,
        now: Date = Date()
    ) -> [String] {
        rankedEntityIds(
            records: all(serverId: serverId),
            currentCategory: currentCategory,
            limit: limit,
            now: now
        )
    }

    /// Drops rows the backend has not confirmed within its own 30-day window, and every row of a
    /// server that no longer exists. Called after a refresh, which is the only time rows are added.
    static func prune(now: Date = Date(), knownServerIds: Set<String>) {
        do {
            try Current.database().write { db in
                let expiry = now.addingTimeInterval(-staleAfter)
                try EntityUsageRecord
                    .filter(Column(DatabaseTables.EntityUsageRecord.updatedAt.rawValue) < expiry)
                    .deleteAll(db)
                // Skipped when there are no servers to compare against: that reads as "every row
                // belongs to an unknown server", and an empty server list is far more likely to
                // mean the manager has not loaded yet than that the user removed every server.
                if !knownServerIds.isEmpty {
                    try EntityUsageRecord
                        .filter(!knownServerIds.contains(Column(DatabaseTables.EntityUsageRecord.serverId.rawValue)))
                        .deleteAll(db)
                }
            }
        } catch {
            Current.Log.error("Failed to prune entity usage, error: \(error)")
        }
    }
}
