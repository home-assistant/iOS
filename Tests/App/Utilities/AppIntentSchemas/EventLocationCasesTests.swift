import GeoToolbox
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Home Assistant stores a location as a free string, so the union the schema requires has to
/// flatten down to one.
@available(iOS 27.0, *)
final class EventLocationCasesTests: XCTestCase {
    /// A `PlaceDescriptor` must carry at least one representation, so every place here has an
    /// address whether or not the test is about the address.
    private func place(named name: String?) -> PlaceDescriptor {
        PlaceDescriptor(representations: [.address("1 High Street")], commonName: name)
    }

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
        XCTAssertEqual(EventLocationCases.place(place(named: "Cafe")).plainText, "Cafe")
    }

    func testAPlaceWithoutANameIsNoLocation() {
        XCTAssertNil(EventLocationCases.place(place(named: nil)).plainText)
        XCTAssertNil(EventLocationCases.place(place(named: "")).plainText)
    }
}
