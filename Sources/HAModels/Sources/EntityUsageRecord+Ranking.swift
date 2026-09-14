import Foundation

public extension EntityUsageRecord {
    /// How long a bucket stays usable after the backend last confirmed it.
    ///
    /// The backend builds each ranking from the last 30 days of the user's service calls, so a
    /// bucket the app has not been able to refresh for that long describes a month it no longer
    /// has any data for. The app only refreshes the bucket it happens to be in, so a household
    /// that never opens the app at night keeps an ageing `night` bucket while the others stay
    /// current — which is why this expires per row rather than per server.
    static let staleAfter: TimeInterval = 30 * 24 * 60 * 60

    /// The entities of one server, most used first.
    ///
    /// The bucket for the current time of day leads, in the order the backend ranked it, because
    /// that is the one answer the backend actually computed for right now. Everything else follows
    /// in a merged order that favours entities used across more of the day: an entity the user
    /// reaches for morning, evening and night says more about the household than one that only
    /// ever appears late at night at rank 1.
    ///
    /// Pass `currentCategory` as `nil` to get the merged order alone, which is what a listing that
    /// is not about "right now" — a picker's suggestions, say — wants.
    ///
    /// `records` are expected to be a single server's: entity ids are only unique within one.
    static func rankedEntityIds(
        records: [EntityUsageRecord],
        currentCategory: EntityUsageTimeCategory? = nil,
        limit: Int? = nil,
        now: Date = Date()
    ) -> [String] {
        let fresh = records.filter { now.timeIntervalSince($0.updatedAt) < staleAfter }

        var ordered: [String] = []
        var seen = Set<String>()
        func append(_ entityId: String) {
            guard seen.insert(entityId).inserted else { return }
            ordered.append(entityId)
        }

        if let currentCategory {
            let current = fresh
                .filter { $0.timeCategory == currentCategory.rawValue }
                .sorted { ($0.rank, $0.entityId) < ($1.rank, $1.entityId) }
            for record in current {
                append(record.entityId)
            }
        }

        for entityId in mergedOrder(of: fresh) {
            append(entityId)
        }

        guard let limit else { return ordered }
        return Array(ordered.prefix(limit))
    }

    /// What is known about one entity once its buckets are folded together.
    private struct UsageStats {
        var buckets: Int
        var bestRank: Int
        var lastSeen: Date
    }

    private static func mergedOrder(of records: [EntityUsageRecord]) -> [String] {
        var stats: [String: UsageStats] = [:]
        for record in records {
            if var existing = stats[record.entityId] {
                existing.buckets += 1
                existing.bestRank = min(existing.bestRank, record.rank)
                existing.lastSeen = max(existing.lastSeen, record.updatedAt)
                stats[record.entityId] = existing
            } else {
                stats[record.entityId] = UsageStats(
                    buckets: 1,
                    bestRank: record.rank,
                    lastSeen: record.updatedAt
                )
            }
        }

        return stats
            .sorted { lhs, rhs in
                // Present in more of the day first, then the best position the backend ever gave
                // it, then the most recently confirmed. The entity id only breaks ties so the
                // order is stable across reads rather than following the dictionary's.
                if lhs.value.buckets != rhs.value.buckets {
                    return lhs.value.buckets > rhs.value.buckets
                }
                if lhs.value.bestRank != rhs.value.bestRank {
                    return lhs.value.bestRank < rhs.value.bestRank
                }
                if lhs.value.lastSeen != rhs.value.lastSeen {
                    return lhs.value.lastSeen > rhs.value.lastSeen
                }
                return lhs.key < rhs.key
            }
            .map(\.key)
    }
}
