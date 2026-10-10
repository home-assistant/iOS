import Foundation
import Shared
import Testing

/// `media_position_updated_at` as Home Assistant writes it, read through the mapper.
struct RemoteMediaTimestampTests {
    /// `datetime.fromisoformat("2026-09-06T12:00:00+00:00").timestamp()`.
    static let noon: TimeInterval = 1_788_696_000

    private func positionUpdatedAt(_ timestamp: Any) throws -> TimeInterval? {
        let entityId = try RemoteMediaFixtures.entityId
        let track = RemoteMediaSnapshotMapper.map(
            serverId: "server-1",
            entityId: entityId,
            state: "playing",
            attributes: ["media_title": "Song", "media_position": 1, "media_position_updated_at": timestamp]
        ).snapshot.track
        return track?.positionUpdatedAtUnix
    }

    /// The forms Core's `isoformat()` writes: with and without fractional seconds, in UTC and with an
    /// offset. For a fractional one the contract is only that it parses to about the right instant.
    @Test(arguments: [
        ("2026-09-06T12:00:00+00:00", RemoteMediaTimestampTests.noon),
        ("2026-09-06T12:00:00Z", RemoteMediaTimestampTests.noon),
        ("2026-09-06T12:00:00.123456+00:00", RemoteMediaTimestampTests.noon + 0.123456),
        ("2026-09-06T08:00:00-04:00", RemoteMediaTimestampTests.noon),
        ("2026-09-06T17:30:00+05:30", RemoteMediaTimestampTests.noon),
    ])
    func homeAssistantTimestampsBecomeUnixSeconds(_ timestamp: String, _ expected: TimeInterval) throws {
        let updatedAt = try positionUpdatedAt(timestamp)
        let parsed = try #require(updatedAt)
        #expect(abs(parsed - expected) < 0.001)
    }

    @Test(arguments: ["", "not a date", "2026-09-06", "12:00:00", "2026-09-06T12:00:00"])
    func notATimestampIsNoTimestamp(_ timestamp: String) throws {
        let updatedAt = try positionUpdatedAt(timestamp)
        #expect(updatedAt == nil)
    }

    @Test func aNonStringIsIgnored() throws {
        let number = try positionUpdatedAt(Self.noon)
        let date = try positionUpdatedAt(Date(timeIntervalSince1970: Self.noon))
        #expect(number == nil)
        #expect(date == nil)
    }
}
