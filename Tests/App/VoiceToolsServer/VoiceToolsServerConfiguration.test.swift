import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct VoiceToolsServerConfigurationTests {
    private func makeDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        return database
    }

    /// Creating the table over an existing database migrates it instead of failing, which is the
    /// path every launch after the first takes.
    @Test func createsOnceThenMigrates() throws {
        let database = try makeDatabase()
        let table = VoiceToolsServerConfigurationTable()

        try table.createIfNeeded(database: database)

        let columns = try database.read { db in
            try db.columns(in: table.tableName).map(\.name)
        }
        #expect(Set(columns) == Set(table.definedColumns))
    }

    @Test func defaultsToOffOnTheWyomingPort() {
        let configuration = VoiceToolsServerConfiguration()

        #expect(configuration.id == VoiceToolsServerConfiguration.singletonID)
        #expect(configuration.isEnabled == false)
        #expect(configuration.port == VoiceToolsServerConfiguration.defaultPort)
        #expect(VoiceToolsServerConfiguration.defaultPort == 10700)
    }

    @MainActor @Test func savesAndReadsBackTheStoredSettings() throws {
        let database = try makeDatabase()
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        VoiceToolsServerConfiguration(isEnabled: true, port: 10801).save()

        #expect(VoiceToolsServerConfiguration.config.isEnabled == true)
        #expect(VoiceToolsServerConfiguration.config.port == 10801)
    }

    /// The singleton row is replaced rather than duplicated, so switching the server off and on
    /// again leaves one row behind rather than a conflict.
    @MainActor @Test func replacesTheSingletonRowOnEverySave() throws {
        let database = try makeDatabase()
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        VoiceToolsServerConfiguration(isEnabled: true, port: 10801).save()
        VoiceToolsServerConfiguration(isEnabled: false, port: 10700).save()

        let rows = try database.read { db in
            try VoiceToolsServerConfiguration.fetchCount(db)
        }
        #expect(rows == 1)
        #expect(VoiceToolsServerConfiguration.config.isEnabled == false)
    }

    /// Nothing has been stored until the user opens the screen, so the accessor has to answer with
    /// the defaults rather than failing.
    @MainActor @Test func readingAnEmptyDatabaseReturnsTheDefaults() throws {
        let database = try makeDatabase()
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        #expect(VoiceToolsServerConfiguration.config == VoiceToolsServerConfiguration())
    }

    /// Columns added by a later migration are NULL on an existing row, which the row initializer
    /// has to read as the defaults instead of failing to decode.
    @MainActor @Test func readsNullColumnsAsDefaults() throws {
        let database = try makeDatabase()
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try database.write { db in
            try db.execute(
                sql: "INSERT INTO voiceToolsServerConfiguration (id, isEnabled, port) VALUES (?, NULL, NULL)",
                arguments: [VoiceToolsServerConfiguration.singletonID]
            )
        }

        let configuration = VoiceToolsServerConfiguration.config
        #expect(configuration.isEnabled == false)
        #expect(configuration.port == VoiceToolsServerConfiguration.defaultPort)
    }
}
