@testable import HomeAssistant
@testable import Shared
import XCTest

/// The calendar as Apple Intelligence sees it, built from the stored one.
@available(iOS 27.0, *)
final class CalendarSchemaEntityTests: XCTestCase {
    private func calendar(id: String = "server-calendar.home", name: String = "Home") -> HACalendar {
        HACalendar(
            id: id,
            serverId: "server",
            entityId: "calendar.home",
            name: name,
            backgroundColor: "#4269d0",
            supportedFeatures: 7,
            sortOrder: 0
        )
    }

    /// The stored id is carried across unchanged: it is what the query resolves the entity back by.
    func testTheStoredCalendarBecomesTheEntity() {
        let sut = CalendarSchemaEntity(calendar: calendar())

        XCTAssertEqual(sut.id, "server-calendar.home")
        XCTAssertEqual(sut.title, "Home")
    }

    func testTheEntityIsShownUnderItsOwnName() {
        let sut = CalendarSchemaEntity(calendar: calendar(name: "Bin collection"))

        XCTAssertEqual(String(localized: sut.displayRepresentation.title), "Bin collection")
    }
}
