import GeoToolbox
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Home Assistant stores a location as a free string, so the union the schema requires has to
/// flatten down to one.
@available(iOS 27.0, *)
final class EventLocationCasesTests: XCTestCase {
    func testTextIsCarriedThrough() {
        XCTAssertEqual(EventLocationCases.text("Dentist's office").plainText, "Dentist's office")
    }

    /// An empty string is no location at all, not a location that is blank.
    func testEmptyTextIsNoLocation() {
        XCTAssertNil(EventLocationCases.text("").plainText)
    }

    /// A structured place is flattened to its name rather than dropped, which is the most Home
    /// Assistant can store of it.
    func testAPlaceIsFlattenedToItsName() {
        let place = PlaceDescriptor(representations: [], commonName: "Cafe")

        XCTAssertEqual(EventLocationCases.place(place).plainText, "Cafe")
    }

    func testAPlaceWithoutANameIsNoLocation() {
        XCTAssertNil(EventLocationCases.place(PlaceDescriptor(representations: [], commonName: nil)).plainText)
        XCTAssertNil(EventLocationCases.place(PlaceDescriptor(representations: [], commonName: "")).plainText)
    }
}
