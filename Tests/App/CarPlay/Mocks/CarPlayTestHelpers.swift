import CarPlay
import GRDB
import HAKit
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Shared plumbing for the CarPlay template tests: draining the main queue the templates update on,
/// reaching the private templates a flow keeps (CarPlay never hands them out without a live
/// `CPInterfaceController`), and building the fixtures they read.
enum CarPlayTestHelpers {
    /// Lets work the templates dispatch onto the main queue (paginated list updates, GRDB
    /// observations) run before the test reads the result.
    static func drainMainQueue(_ testCase: XCTestCase, cycles: Int = 3) {
        let drained = testCase.expectation(description: "main queue drained")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    drained.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        testCase.wait(for: [drained], timeout: 30)
    }

    /// Reads a stored property by name, private ones included, without changing the type's API.
    static func storedValue(named name: String, of object: Any) -> Any? {
        Mirror(reflecting: object).children.first(where: { $0.label == name })?.value
    }

    /// The `CPListTemplate` a flow or template keeps privately under `name`.
    static func listTemplate(named name: String, of object: Any) -> CPListTemplate? {
        storedValue(named: name, of: object) as? CPListTemplate
    }

    /// Every row of a list template, flattened across its sections.
    static func items(of template: CPListTemplate) -> [any CPListTemplateItem] {
        template.sections.flatMap(\.items)
    }

    /// Plain rows only (`CPListItem`), skipping iOS 26 image-row tiles.
    static func listItems(of template: CPListTemplate) -> [CPListItem] {
        items(of: template).compactMap { $0 as? CPListItem }
    }

    /// Runs a row's tap handler the way CarPlay would.
    static func tap(_ item: CPListItem) {
        item.handler?(item, {})
    }

    /// Runs the tap handler of the element at `index` of an iOS 26 image-row tile.
    static func tap(_ item: CPListImageRowItem, elementAt index: Int) {
        item.listImageRowHandler?(item, index, {})
    }

    /// Taps a row whatever its kind: the row itself, or the first element of an image-row tile.
    static func tapAny(_ item: any CPListTemplateItem) {
        if let row = item as? CPListItem {
            tap(row)
        } else if let tile = item as? CPListImageRowItem {
            tap(tile, elementAt: 0)
        }
    }

    /// Visible text of the given rows (plain rows only).
    static func texts(of template: CPListTemplate) -> [String] {
        listItems(of: template).compactMap(\.text)
    }

    static func entity(
        _ entityId: String,
        state: String = "on",
        attributes: [String: Any] = [:]
    ) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    static func states(_ entities: [HAEntity]) -> HACachedStates {
        HACachedStates(entitiesDictionary: Dictionary(
            entities.map { ($0.entityId, $0) },
            uniquingKeysWith: { first, _ in first }
        ))
    }

    /// A fresh in-memory database carrying every app table, so a test reads and writes its own
    /// configuration rather than the machine's.
    static func makeDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    static func save(_ config: CarPlayConfig, in database: DatabaseQueue) throws {
        try database.write { db in
            try config.insert(db, onConflict: .replace)
        }
    }

    static func storedConfig(in database: DatabaseQueue) throws -> CarPlayConfig? {
        try database.read { db in
            try CarPlayConfig.fetchOne(db)
        }
    }
}
