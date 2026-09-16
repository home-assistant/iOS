@testable import HomeAssistant
import XCTest

/// The calendar shapes Home Assistant has no equivalent for.
///
/// Apple's schema requires the properties, so the types exist and have to stay well formed even
/// though nothing ever produces a value for them: a case missing its name, or two cases sharing
/// one, would surface in the Shortcuts picker as a blank or a duplicate row.
@available(iOS 27.0, *)
final class CalendarSchemaPlaceholderTests: XCTestCase {
    func testEveryAttendeeStatusIsNamedDistinctly() {
        let all: [CalendarAttendeeStatusSchemaEnum] = [.accepted, .declined, .tentative, .pending]
        let titles = all.compactMap { CalendarAttendeeStatusSchemaEnum.caseDisplayRepresentations[$0] }

        XCTAssertEqual(titles.count, all.count)
        XCTAssertEqual(Set(titles.map { String(localized: $0.title) }).count, all.count)
    }

    func testEveryAttendeeTypeIsNamedDistinctly() {
        let all: [CalendarAttendeeTypeSchemaEnum] = [.person, .room, .resource]
        let titles = all.compactMap { CalendarAttendeeTypeSchemaEnum.caseDisplayRepresentations[$0] }

        XCTAssertEqual(titles.count, all.count)
        XCTAssertEqual(Set(titles.map { String(localized: $0.title) }).count, all.count)
    }

    func testEveryEventStatusIsNamedDistinctly() {
        let all: [CalendarEventStatusSchemaEnum] = [.confirmed, .tentative, .cancelled]
        let titles = all.compactMap { CalendarEventStatusSchemaEnum.caseDisplayRepresentations[$0] }

        XCTAssertEqual(titles.count, all.count)
        XCTAssertEqual(Set(titles.map { String(localized: $0.title) }).count, all.count)
    }

    /// Home Assistant reports no attendees, so the transient entity only ever appears empty — and
    /// "empty" has to mean an unset person rather than a half-filled one.
    func testTheAttendeePlaceholderStartsEmpty() {
        let sut = CalendarAttendeeSchemaEntity()

        XCTAssertNil(sut.status)
        XCTAssertNil(sut.type)
        XCTAssertFalse(sut.isAttendanceOptional)
        XCTAssertFalse(String(localized: sut.displayRepresentation.title).isEmpty)
    }
}
