import GeoToolbox
@testable import HomeAssistant
import XCTest

/// The reminder shapes Home Assistant has no equivalent for; see
/// `CalendarSchemaPlaceholderTests` for why they are checked at all.
@available(iOS 27.0, *)
final class ReminderSchemaPlaceholderTests: XCTestCase {
    /// One kind of list, named by the case the schema requires.
    func testTheOnlyListTypeIsNamed() {
        let representation = ReminderListTypeSchemaEnum.caseDisplayRepresentations[.standard]

        XCTAssertEqual(ReminderListTypeSchemaEnum.caseDisplayRepresentations.count, 1)
        XCTAssertNotNil(representation)
        XCTAssertFalse(String(localized: representation!.title).isEmpty)
    }

    func testBothLocationTriggerEventsAreNamedDistinctly() {
        let all: [LocationTriggerEventSchemaEnum] = [.arrive, .depart]
        let titles = all.compactMap { LocationTriggerEventSchemaEnum.caseDisplayRepresentations[$0] }

        XCTAssertEqual(titles.count, all.count)
        XCTAssertEqual(Set(titles.map { String(localized: $0.title) }).count, all.count)
    }

    /// Home Assistant to-do lists have no sections, so the transient entity only ever appears
    /// empty, carrying the empty list that exists for exactly this.
    func testTheSectionPlaceholderStartsEmpty() {
        let sut = ReminderSectionSchemaEntity()

        XCTAssertTrue(sut.name.isEmpty)
        XCTAssertTrue(sut.list.id.isEmpty)
        XCTAssertTrue(sut.list.entityId.isEmpty)
    }

    /// Home Assistant to-do items have no location trigger; arriving is the schema's own default.
    func testTheLocationTriggerPlaceholderStartsEmpty() {
        let sut = LocationTriggerSchemaEntity()

        XCTAssertEqual(sut.event, .arrive)
        XCTAssertNil(sut.place.commonName)
        XCTAssertFalse(String(localized: sut.displayRepresentation.title).isEmpty)
    }
}
