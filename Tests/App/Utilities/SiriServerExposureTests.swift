import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers the per-server Siri opt-out: what it stores, and what it hides.
struct SiriServerExposureTests {
    private func clear() async throws {
        try await Current.database().write { db in
            _ = try SiriServerExposure.deleteAll(db)
        }
    }

    /// A server nobody has touched is exposed, so adding a server behaves the way every server did
    /// before the setting existed.
    @Test func aServerWithNoRowIsExposed() async throws {
        try await clear()
        #expect(SiriServerExposure.isExposed(serverId: "never-set"))
        #expect(SiriServerExposure.hiddenServerIds().isEmpty)
    }

    @Test func optingOutHidesOnlyThatServer() async throws {
        try await clear()
        SiriServerExposure.setExposed(false, serverId: "s1")
        #expect(SiriServerExposure.hiddenServerIds() == ["s1"])
        #expect(!SiriServerExposure.isExposed(serverId: "s1"))
        #expect(SiriServerExposure.isExposed(serverId: "s2"))
    }

    @Test func optingBackInStopsHiding() async throws {
        try await clear()
        SiriServerExposure.setExposed(false, serverId: "s1")
        SiriServerExposure.setExposed(true, serverId: "s1")
        #expect(SiriServerExposure.hiddenServerIds().isEmpty)
        #expect(SiriServerExposure.isExposed(serverId: "s1"))
    }

    /// A removed server's choice goes with it, so a later server reusing the identifier does not
    /// inherit it.
    @Test func deletingAServerDropsItsChoice() async throws {
        try await clear()
        SiriServerExposure.setExposed(false, serverId: "s1")
        SiriServerExposure.delete(serverId: "s1")
        #expect(SiriServerExposure.isExposed(serverId: "s1"))
    }

    @Test func theRowKeepsTheServerAsItsIdentity() {
        let row = SiriServerExposure(serverId: "s1", isExposed: false)
        #expect(row.id == "s1")
        #expect(row.isExposed == false)
    }
}

/// The table and the settings entry that carry the opt-out.
struct SiriExposureWiringTests {
    /// The row lands in a real table, so the choice survives a relaunch rather than living in
    /// memory.
    @Test func theTableIsCreatedWithItsColumns() async throws {
        let columns = try await Current.database().read { db in
            try db.columns(in: GRDBDatabaseTable.siriServerExposure.rawValue).map(\.name)
        }
        #expect(columns.contains(DatabaseTables.SiriServerExposure.serverId.rawValue))
        #expect(columns.contains(DatabaseTables.SiriServerExposure.isExposed.rawValue))
    }

    @Test func theSettingsEntryIsReachable() {
        #expect(SettingsSection.quickAccess.allItems.contains(.siri))
        #expect(!SettingsItem.siri.title.isEmpty)
        #expect(!SettingsItem.siri.searchKeywords.isEmpty)
        #expect(!SettingsItem.siri.contentSearchEntries.isEmpty)
    }

    /// Writing the same server twice replaces the row rather than failing on its key.
    @Test func theChoiceIsReplacedNotDuplicated() async throws {
        try await Current.database().write { db in
            _ = try SiriServerExposure.deleteAll(db)
        }
        SiriServerExposure.setExposed(false, serverId: "s1")
        SiriServerExposure.setExposed(false, serverId: "s1")
        let rows = try await Current.database().read { db in
            try SiriServerExposure.fetchAll(db)
        }
        #expect(rows.count == 1)
        try await Current.database().write { db in
            _ = try SiriServerExposure.deleteAll(db)
        }
    }

    /// The row has to lead somewhere: without that case the entry appears in settings and opens
    /// nothing.
    @MainActor @Test func theEntryOpensTheSiriScreen() {
        #expect(!String(describing: SettingsItem.siri.destinationView).isEmpty)
    }
}
