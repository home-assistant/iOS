@testable import HomeAssistant
@testable import Shared
import XCTest

/// The to-do list as Apple Intelligence sees it.
@available(iOS 27.0, *)
final class ReminderListSchemaEntityTests: XCTestCase {
    private func entity(name: String = "Shopping") -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: "server", entityId: "todo.shopping"),
            entityId: "todo.shopping",
            serverId: "server",
            domain: "todo",
            name: name,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: nil,
            isHidden: nil
        )
    }

    /// The entity id and server are kept off the schema shape but carried on the entity, because
    /// they are what the `todo` services address.
    func testTheStoredEntityBecomesTheList() {
        let sut = ReminderListSchemaEntity(entity: entity())

        XCTAssertEqual(sut.id, ServerEntity.uniqueId(serverId: "server", entityId: "todo.shopping"))
        XCTAssertEqual(sut.name, "Shopping")
        XCTAssertEqual(sut.entityId, "todo.shopping")
        XCTAssertEqual(sut.serverId, "server")
    }

    /// Home Assistant has one kind of to-do list, and the schema requires that case by name.
    func testEveryListIsAStandardOne() {
        XCTAssertEqual(ReminderListSchemaEntity(entity: entity()).type, .standard)
        XCTAssertEqual(ReminderListSchemaEntity().type, .standard)
    }

    /// The empty list exists only so the transient section entity can carry one; it addresses
    /// nothing, and has to be recognisable as such.
    func testTheEmptyListAddressesNothing() {
        let sut = ReminderListSchemaEntity()

        XCTAssertTrue(sut.id.isEmpty)
        XCTAssertTrue(sut.entityId.isEmpty)
        XCTAssertTrue(sut.serverId.isEmpty)
        XCTAssertTrue(sut.name.isEmpty)
    }

    func testTheListIsShownUnderItsOwnName() {
        let sut = ReminderListSchemaEntity(entity: entity(name: "Weekly shop"))

        XCTAssertEqual(String(localized: sut.displayRepresentation.title), "Weekly shop")
    }
}
