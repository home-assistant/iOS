import Foundation
import GRDB
@testable import Shared
import Testing

/// The cache of the entities the signed-in user controls most.
///
/// What is worth protecting here is the merge: the backend only ever answers for one time of day,
/// so the ranking the app shows is assembled from several of those answers, and a regression in
/// how they are folded together is invisible until a widget quietly shows the wrong entities.
///
/// Serialized because the database cases swap `Current.database`.
@Suite(.serialized)
struct EntityUsageRecordTests {
    private static let noon = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Time categories

    /// The buckets have to agree with the backend's, or a response gets filed under the wrong one.
    @Test func hoursMapToTheBackendsBuckets() {
        #expect(EntityUsageTimeCategory.forHour(6) == .morning)
        #expect(EntityUsageTimeCategory.forHour(11) == .morning)
        #expect(EntityUsageTimeCategory.forHour(12) == .afternoon)
        #expect(EntityUsageTimeCategory.forHour(17) == .afternoon)
        #expect(EntityUsageTimeCategory.forHour(18) == .evening)
        #expect(EntityUsageTimeCategory.forHour(21) == .evening)
        #expect(EntityUsageTimeCategory.forHour(22) == .night)
        #expect(EntityUsageTimeCategory.forHour(5) == .night)
    }

    // MARK: - Merging buckets

    /// The bucket for right now leads, in the order the backend ranked it: it is the only answer
    /// the backend actually computed for this time of day.
    @Test func currentBucketLeadsInItsOwnOrder() {
        let records = [
            Self.record("light.hall", .evening, rank: 1),
            Self.record("light.kitchen", .evening, rank: 0),
            Self.record("light.bedroom", .night, rank: 0),
        ]

        let ranked = EntityUsageRecord.rankedEntityIds(
            records: records,
            currentCategory: .evening,
            now: Self.noon
        )

        #expect(Array(ranked.prefix(2)) == ["light.kitchen", "light.hall"])
        #expect(ranked.contains("light.bedroom"))
    }

    /// Outside the leading bucket, an entity used across more of the day outranks one that only
    /// ever appears in a single bucket — even at the top of it.
    @Test func entitiesUsedAcrossMoreOfTheDayRankHigher() {
        let records = [
            Self.record("light.hall", .morning, rank: 3),
            Self.record("light.hall", .evening, rank: 4),
            Self.record("light.hall", .night, rank: 2),
            Self.record("switch.desk", .morning, rank: 0),
        ]

        let ranked = EntityUsageRecord.rankedEntityIds(records: records, now: Self.noon)

        #expect(ranked == ["light.hall", "switch.desk"])
    }

    /// Within the same number of buckets, the best position the backend ever gave an entity wins.
    @Test func bestRankBreaksTheTie() {
        let records = [
            Self.record("light.hall", .morning, rank: 2),
            Self.record("switch.desk", .morning, rank: 1),
        ]

        let ranked = EntityUsageRecord.rankedEntityIds(records: records, now: Self.noon)

        #expect(ranked == ["switch.desk", "light.hall"])
    }

    /// A bucket the app has not refreshed within the backend's own 30-day window describes a month
    /// the backend no longer has data for, so it drops out rather than pinning a stale entity up top.
    @Test func staleBucketsAreIgnored() {
        let records = [
            Self.record("light.hall", .morning, rank: 0, updatedAt: Self.noon.addingTimeInterval(-40 * 24 * 60 * 60)),
            Self.record("switch.desk", .morning, rank: 5),
        ]

        let ranked = EntityUsageRecord.rankedEntityIds(records: records, now: Self.noon)

        #expect(ranked == ["switch.desk"])
    }

    @Test func limitCutsTheList() {
        let records = (0 ..< 5).map { Self.record("light.\($0)", .morning, rank: $0) }

        let ranked = EntityUsageRecord.rankedEntityIds(records: records, limit: 2, now: Self.noon)

        #expect(ranked == ["light.0", "light.1"])
    }

    // MARK: - Storage

    /// A bucket is replaced, not merged: an entity missing from the backend's new answer is one the
    /// user stopped reaching for, and keeping its row would pin it near the top forever.
    @Test func savingABucketReplacesIt() throws {
        try withDatabase {
            EntityUsageRecord.save(
                entityIds: ["light.hall", "light.kitchen"],
                serverId: "A",
                timeCategory: .morning,
                now: Self.noon
            )
            EntityUsageRecord.save(
                entityIds: ["light.kitchen"],
                serverId: "A",
                timeCategory: .morning,
                now: Self.noon
            )

            #expect(EntityUsageRecord.rankedEntityIds(serverId: "A", now: Self.noon) == ["light.kitchen"])
        }
    }

    /// Each bucket is stored on its own, so the buckets a day's use fills in add up to more than
    /// the eight entities any single response carries.
    @Test func bucketsAccumulateAcrossTheDay() throws {
        try withDatabase {
            EntityUsageRecord.save(entityIds: ["light.hall"], serverId: "A", timeCategory: .morning, now: Self.noon)
            EntityUsageRecord.save(entityIds: ["light.bed"], serverId: "A", timeCategory: .night, now: Self.noon)
            EntityUsageRecord.save(entityIds: ["light.other"], serverId: "B", timeCategory: .morning, now: Self.noon)

            let ranked = EntityUsageRecord.rankedEntityIds(serverId: "A", now: Self.noon)

            #expect(Set(ranked) == ["light.hall", "light.bed"])
        }
    }

    /// Pruning clears what the backend's window no longer covers, and anything left behind by a
    /// server the user has since removed.
    @Test func pruningDropsStaleRowsAndUnknownServers() throws {
        try withDatabase {
            let longAgo = Self.noon.addingTimeInterval(-40 * 24 * 60 * 60)
            EntityUsageRecord.save(entityIds: ["light.old"], serverId: "A", timeCategory: .morning, now: longAgo)
            EntityUsageRecord.save(entityIds: ["light.hall"], serverId: "A", timeCategory: .evening, now: Self.noon)
            EntityUsageRecord.save(entityIds: ["light.gone"], serverId: "B", timeCategory: .evening, now: Self.noon)

            EntityUsageRecord.prune(now: Self.noon, knownServerIds: ["A"])

            #expect(EntityUsageRecord.all(serverId: "A").map(\.entityId) == ["light.hall"])
            #expect(EntityUsageRecord.all(serverId: "B").isEmpty)
        }
    }

    /// An empty server list reads as "the server manager has not loaded yet", not as "the user
    /// removed every server" — wiping the cache on a cold start would cost every widget its tiles.
    @Test func pruningKeepsRowsWhenNoServersAreKnown() throws {
        try withDatabase {
            EntityUsageRecord.save(entityIds: ["light.hall"], serverId: "A", timeCategory: .evening, now: Self.noon)

            EntityUsageRecord.prune(now: Self.noon, knownServerIds: [])

            #expect(EntityUsageRecord.all(serverId: "A").map(\.entityId) == ["light.hall"])
        }
    }

    private static func record(
        _ entityId: String,
        _ timeCategory: EntityUsageTimeCategory,
        rank: Int,
        updatedAt: Date = EntityUsageRecordTests.noon
    ) -> EntityUsageRecord {
        EntityUsageRecord(
            serverId: "A",
            entityId: entityId,
            timeCategory: timeCategory,
            rank: rank,
            updatedAt: updatedAt
        )
    }

    private func withDatabase(_ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }

        let database = try DatabaseQueue(path: ":memory:")
        try EntityUsageRecordTable().createIfNeeded(database: database)
        Current.database = { database }

        try body()
    }
}
