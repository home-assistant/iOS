@testable import HomeAssistant
@testable import Shared
import XCTest

@available(iOS 27.0, *)
final class ReminderListSchemaEntityDisplayTests: AppIntentSchemaTestCase {
    func testWithOneServerTheListShowsOnlyItsName() throws {
        let sut = try ReminderListSchemaEntity(entity: seedTodoList(name: "Shopping"))

        XCTAssertEqual(String(localized: sut.displayRepresentation.title), "Shopping")
        XCTAssertNil(sut.displayRepresentation.subtitle)
    }

    func testWithSeveralServersTheListIsToldApartByItsServer() throws {
        server.update { $0.remoteName = "Home" }
        let other = servers.addFake()
        other.update { $0.remoteName = "Cabin" }
        let home = try ReminderListSchemaEntity(entity: seedTodoList(name: "Shopping"))
        let cabin = try ReminderListSchemaEntity(
            entity: seedTodoList(name: "Shopping", onServer: other.identifier.rawValue)
        )

        XCTAssertEqual(String(localized: XCTUnwrap(home.displayRepresentation.subtitle)), "Home")
        XCTAssertEqual(String(localized: XCTUnwrap(cabin.displayRepresentation.subtitle)), "Cabin")
    }

    func testAListWhoseServerIsGoneHasNoSubtitle() throws {
        servers.addFake()
        let sut = try ReminderListSchemaEntity(entity: seedTodoList(onServer: "missing-server"))

        XCTAssertNil(sut.displayRepresentation.subtitle)
    }
}
