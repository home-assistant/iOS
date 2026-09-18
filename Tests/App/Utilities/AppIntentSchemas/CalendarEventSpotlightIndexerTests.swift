import CoreSpotlight
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Keeping Spotlight's copy of the cached calendar events in step.
///
/// The index belongs to the system and can refuse a write in a test host, so what is asserted here
/// is the bookkeeping the indexer owns either way: it records exactly the identifiers it wrote, or
/// nothing at all when it could not write, and it never throws at a caller that could do nothing
/// about it.
@available(iOS 27.0, *)
final class CalendarEventSpotlightIndexerTests: AppIntentSchemaTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "CalendarEventSpotlightIndexerTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private var index: CSSearchableIndex {
        CSSearchableIndex(name: "CalendarEventSpotlightIndexerTests")
    }

    private var indexedIds: [String]? {
        defaults.stringArray(forKey: "spotlightIndexedCalendarEventIds")
    }

    /// Nothing cached means nothing to write and nothing stale to remove, so the pass reaches the
    /// end on its own and records that the index is empty — which is what stops the next pass from
    /// believing Spotlight still holds something.
    func testAnEmptyCacheRecordsThatNothingIsIndexed() async {
        await CalendarEventSpotlightIndexer.reindex(index: index, defaults: defaults)

        XCTAssertEqual(indexedIds, [])
    }

    func testAPassRecordsExactlyTheEventsItWroteOrNothingAtAll() async throws {
        try seedCalendar()
        try seedEvent(id: "event-1", summary: "Dentist")

        await CalendarEventSpotlightIndexer.reindex(index: index, defaults: defaults)

        XCTAssertTrue(
            indexedIds == nil || indexedIds == ["event-1"],
            "recorded \(String(describing: indexedIds)), which is neither the written events nor nothing"
        )
    }

    /// Events on an opted-out server never reach the index, so they must not be recorded as though
    /// they had.
    func testEventsOnAnOptedOutServerAreNotIndexed() async throws {
        try seedCalendar()
        try seedEvent(id: "event-1")
        try hideFromSiri(serverId)

        await CalendarEventSpotlightIndexer.reindex(index: index, defaults: defaults)

        XCTAssertEqual(indexedIds, [])
    }

    /// Nowhere to record what was written is not a reason to fail: the pass still runs, and the
    /// next one simply starts from nothing.
    func testWithoutSomewhereToRecordItThePassStillRuns() async {
        await CalendarEventSpotlightIndexer.reindex(index: index, defaults: nil)
    }

    /// The pass mirrors the cache and runs on every foreground, so it must not read a calendar from
    /// the server the way a Siri query does.
    func testAPassReadsTheCacheWithoutGoingToTheServer() async throws {
        try seedCalendar()
        try seedEvent()

        await CalendarEventSpotlightIndexer.reindex(index: index, defaults: defaults)

        XCTAssertTrue(calendarsModel.eventsRequests.isEmpty)
    }
}
