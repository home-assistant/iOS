import Foundation
import GRDB

/// One entity the signed-in user commonly controls, as the backend ranked it for a time of day.
///
/// The source is `usage_prediction/common_control`, which the backend computes per user from the
/// last 30 days of service calls — every interaction made under that user's token, from the web
/// frontend, this app, its widgets or Assist alike. A single response is narrow: at most eight
/// entities, and only for the bucket the server happens to be in when asked.
///
/// Rows are therefore written a bucket at a time, whenever the app or a widget asks during that
/// part of the day, and accumulate into the wider ranking a single response never carries. See
/// `EntityUsageRecord.rankedEntityIds(records:currentCategory:limit:)` for how they are merged, and
/// `EntityUsageRecord+Queries` in `Shared` for the reads and writes.
public struct EntityUsageRecord: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    /// `serverId-timeCategory-entityId`: one row per entity, per bucket, per server.
    public let id: String
    public let serverId: String
    public let entityId: String
    /// The `EntityUsageTimeCategory` raw value this ranking was returned for. Stored raw so a
    /// bucket a newer backend introduces is kept rather than dropped when it is read back.
    public let timeCategory: String
    /// 0-based position in the backend's response for this bucket; lower means used more.
    public let rank: Int
    /// When this bucket was last written. Buckets go stale on their own schedule — the app only
    /// refreshes the one it is in — so expiry is per row, not per server.
    public let updatedAt: Date

    public init(
        id: String,
        serverId: String,
        entityId: String,
        timeCategory: String,
        rank: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.serverId = serverId
        self.entityId = entityId
        self.timeCategory = timeCategory
        self.rank = rank
        self.updatedAt = updatedAt
    }

    public init(
        serverId: String,
        entityId: String,
        timeCategory: EntityUsageTimeCategory,
        rank: Int,
        updatedAt: Date
    ) {
        self.init(
            id: Self.id(serverId: serverId, timeCategory: timeCategory, entityId: entityId),
            serverId: serverId,
            entityId: entityId,
            timeCategory: timeCategory.rawValue,
            rank: rank,
            updatedAt: updatedAt
        )
    }

    public static func id(serverId: String, timeCategory: EntityUsageTimeCategory, entityId: String) -> String {
        "\(serverId)-\(timeCategory.rawValue)-\(entityId)"
    }
}
