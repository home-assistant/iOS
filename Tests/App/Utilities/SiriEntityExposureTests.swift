import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct SiriEntityExposureTests {
    private let calendar = Domain.calendar.rawValue
    private let todo = Domain.todo.rawValue

    private func withCleanRows(_ body: () async throws -> Void) async throws {
        try await clear()
        do {
            try await body()
        } catch {
            try await clear()
            throw error
        }
        try await clear()
    }

    private func clear() async throws {
        try await Current.database().write { db in
            _ = try SiriEntityExposure.deleteAll(db)
        }
    }

    @Test func anEntityWithNoRowIsExposedAndNotTheDefault() async throws {
        try await withCleanRows {
            #expect(SiriEntityExposure.isExposed(serverId: "s1", entityId: "todo.a"))
            #expect(SiriEntityExposure.hiddenEntityIds().isEmpty)
            #expect(SiriEntityExposure.defaultEntityId(serverId: "s1", domain: todo) == nil)
        }
    }

    @Test func switchingOffHidesOnlyThatEntity() async throws {
        try await withCleanRows {
            SiriEntityExposure.setExposed(false, serverId: "s1", entityId: "todo.a", domain: todo)
            #expect(SiriEntityExposure.hiddenEntityIds() == ["s1-todo.a"])
            #expect(SiriEntityExposure.hiddenEntityIds(domain: todo) == ["s1-todo.a"])
            #expect(SiriEntityExposure.hiddenEntityIds(domain: calendar).isEmpty)
            #expect(!SiriEntityExposure.isExposed(serverId: "s1", entityId: "todo.a"))
            #expect(SiriEntityExposure.isExposed(serverId: "s1", entityId: "todo.b"))
        }
    }

    @Test func switchingBackOnStopsHiding() async throws {
        try await withCleanRows {
            SiriEntityExposure.setExposed(false, serverId: "s1", entityId: "todo.a", domain: todo)
            SiriEntityExposure.setExposed(true, serverId: "s1", entityId: "todo.a", domain: todo)
            #expect(SiriEntityExposure.hiddenEntityIds().isEmpty)
        }
    }

    @Test func settingADefaultReplacesThePreviousOneForThatServerAndDomain() async throws {
        try await withCleanRows {
            SiriEntityExposure.setDefault(entityId: "todo.a", serverId: "s1", domain: todo)
            SiriEntityExposure.setDefault(entityId: "calendar.a", serverId: "s1", domain: calendar)
            SiriEntityExposure.setDefault(entityId: "todo.z", serverId: "s2", domain: todo)
            SiriEntityExposure.setDefault(entityId: "todo.b", serverId: "s1", domain: todo)

            #expect(SiriEntityExposure.defaultEntityId(serverId: "s1", domain: todo) == "s1-todo.b")
            #expect(SiriEntityExposure.defaultEntityId(serverId: "s1", domain: calendar) == "s1-calendar.a")
            #expect(SiriEntityExposure.defaultEntityId(serverId: "s2", domain: todo) == "s2-todo.z")
            #expect(SiriEntityExposure.defaultEntityIds(domain: todo) == ["s1-todo.b", "s2-todo.z"])
        }
    }

    @Test func clearingTheDefaultLeavesNone() async throws {
        try await withCleanRows {
            SiriEntityExposure.setDefault(entityId: "todo.a", serverId: "s1", domain: todo)
            SiriEntityExposure.setDefault(entityId: nil, serverId: "s1", domain: todo)
            #expect(SiriEntityExposure.defaultEntityId(serverId: "s1", domain: todo) == nil)
        }
    }

    @Test func aDefaultStaysTheDefaultWhenSwitchedOnAgain() async throws {
        try await withCleanRows {
            SiriEntityExposure.setDefault(entityId: "todo.a", serverId: "s1", domain: todo)
            SiriEntityExposure.setExposed(true, serverId: "s1", entityId: "todo.a", domain: todo)
            #expect(SiriEntityExposure.defaultEntityId(serverId: "s1", domain: todo) == "s1-todo.a")
        }
    }

    @Test func switchingOffTheDefaultDropsItAsTheDefault() async throws {
        try await withCleanRows {
            SiriEntityExposure.setDefault(entityId: "todo.a", serverId: "s1", domain: todo)
            SiriEntityExposure.setExposed(false, serverId: "s1", entityId: "todo.a", domain: todo)
            #expect(SiriEntityExposure.defaultEntityId(serverId: "s1", domain: todo) == nil)
            #expect(SiriEntityExposure.defaultEntityIds(domain: todo).isEmpty)
        }
    }

    @Test func deletingAServerDropsItsRows() async throws {
        try await withCleanRows {
            SiriEntityExposure.setExposed(false, serverId: "s1", entityId: "todo.a", domain: todo)
            SiriEntityExposure.setExposed(false, serverId: "s2", entityId: "todo.a", domain: todo)
            SiriEntityExposure.delete(serverId: "s1")
            #expect(SiriEntityExposure.hiddenEntityIds() == ["s2-todo.a"])
        }
    }

    @Test func theRowIsKeyedByServerAndEntity() {
        let row = SiriEntityExposure(
            serverId: "s1",
            entityId: "todo.a",
            domain: "todo",
            isExposed: true,
            isDefault: true
        )
        #expect(row.id == "s1-todo.a")
        #expect(row.isDefault)
    }

    @Test func theTableMigratesInPlaceWhenItAlreadyExists() throws {
        let database = try DatabaseQueue(path: ":memory:")
        let table = SiriEntityExposureTable()
        try database.write { db in
            try db.create(table: table.tableName) { t in
                t.primaryKey(DatabaseTables.SiriEntityExposure.id.rawValue, .text).notNull()
                t.column(DatabaseTables.SiriEntityExposure.serverId.rawValue, .text).notNull()
                t.column(DatabaseTables.SiriEntityExposure.entityId.rawValue, .text).notNull()
                t.column(DatabaseTables.SiriEntityExposure.domain.rawValue, .text).notNull()
                t.column(DatabaseTables.SiriEntityExposure.isExposed.rawValue, .boolean).notNull()
            }
        }
        try table.createIfNeeded(database: database)

        let columns = try database.read { db in
            try db.columns(in: table.tableName).map(\.name)
        }
        #expect(columns.sorted() == table.definedColumns.sorted())
    }

    @Test func writesFailQuietlyWhenTheDatabaseIsUnusable() throws {
        let previous = Current.database
        defer { Current.database = previous }
        let empty = try DatabaseQueue(path: ":memory:")
        Current.database = { empty }

        SiriEntityExposure.setExposed(false, serverId: "s1", entityId: "todo.a", domain: todo)
        SiriEntityExposure.setDefault(entityId: "todo.a", serverId: "s1", domain: todo)
        SiriEntityExposure.delete(serverId: "s1")

        #expect(SiriEntityExposure.hiddenEntityIds().isEmpty)
        #expect(SiriEntityExposure.isExposed(serverId: "s1", entityId: "todo.a"))
        #expect(SiriEntityExposure.defaultEntityId(serverId: "s1", domain: todo) == nil)
    }

    @Test func theTableIsCreatedWithItsColumns() async throws {
        let columns = try await Current.database().read { db in
            try db.columns(in: GRDBDatabaseTable.siriEntityExposure.rawValue).map(\.name)
        }
        for column in DatabaseTables.SiriEntityExposure.allCases {
            #expect(columns.contains(column.rawValue))
        }
    }
}
