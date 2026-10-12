import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct SendspinPlayerConfigurationTests {
    private func withTestDatabase(_ work: () throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }
        try work()
    }

    @Test func defaultsToOffAndOpenToApprovedServers() {
        let configuration = SendspinPlayerConfiguration()
        #expect(configuration.id == SendspinPlayerConfiguration.singletonID)
        #expect(configuration.isEnabled == false)
        #expect(configuration.playerName == nil)
        #expect(configuration.volume == 100)
        #expect(configuration.outputDelayMs == 0)
        #expect(configuration.allowsUnpairedAccess)
    }

    @Test func createsOnceThenMigrates() throws {
        let database = try DatabaseQueue(path: ":memory:")
        let table = SendspinPlayerConfigurationTable()
        try table.createIfNeeded(database: database)
        try table.createIfNeeded(database: database)
        let columns = try database.read { db in
            try db.columns(in: table.tableName).map(\.name)
        }
        #expect(Set(columns) == Set(table.definedColumns))
    }

    @MainActor @Test func savesAndReadsBackTheSingletonRow() throws {
        try withTestDatabase {
            #expect(SendspinPlayerConfiguration.config == SendspinPlayerConfiguration())
            SendspinPlayerConfiguration(isEnabled: true, playerName: "Kitchen", volume: 30, outputDelayMs: 120).save()
            SendspinPlayerConfiguration(isEnabled: true, playerName: "Den", volume: 40, isMuted: true).save()
            let stored = SendspinPlayerConfiguration.config
            #expect(stored.playerName == "Den")
            #expect(stored.volume == 40)
            #expect(stored.isMuted)
            let count = try Current.database().read { db in try SendspinPlayerConfiguration.fetchCount(db) }
            #expect(count == 1)
        }
    }

    /// What a session reports is kept inside the ranges the specification allows.
    @Test func clampsWhatItReportsToServers() {
        let settings = SendspinPlayerConfiguration(playerName: "  Kitchen ", volume: 140, outputDelayMs: 9000)
            .playerSettings
        #expect(settings.name == "Kitchen")
        #expect(settings.volume == 100)
        #expect(settings.outputDelayMs == SendspinPlayerConfiguration.maximumOutputDelayMs)
    }

    @Test func followsTheDeviceNameWhenNoneIsSet() {
        #expect(!SendspinPlayerConfiguration(playerName: "   ").resolvedPlayerName.isEmpty)
    }
}
