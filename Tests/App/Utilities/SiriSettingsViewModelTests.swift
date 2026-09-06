import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers the Siri settings screen's rows and the filtering they drive.
@MainActor
struct SiriSettingsViewModelTests {
    private func clear() async throws {
        try await Current.database().write { db in
            _ = try SiriServerExposure.deleteAll(db)
        }
    }

    private func withFakeServers(_ body: ([Server]) async throws -> Void) async throws {
        let previous = Current.servers
        defer { Current.servers = previous }
        let manager = FakeServerManager(initial: 0)
        let first = manager.addFake()
        let second = manager.addFake()
        Current.servers = manager
        try await body([first, second])
    }

    @Test func listsEveryServerAsExposedByDefault() async throws {
        try await clear()
        try await withFakeServers { servers in
            let model = SiriSettingsViewModel()
            model.load()
            let everyRowExposed = model.rows.allSatisfy(\.isExposed)
            #expect(model.rows.count == servers.count)
            #expect(everyRowExposed)
        }
    }

    @Test func turningAServerOffIsRememberedAndReloaded() async throws {
        try await clear()
        try await withFakeServers { servers in
            let hidden = servers[0].identifier.rawValue
            let model = SiriSettingsViewModel()
            model.load()
            model.setExposed(false, serverId: hidden)

            #expect(model.rows.first { $0.id == hidden }?.isExposed == false)

            // A fresh screen reads the same choice back out of the database.
            let reopened = SiriSettingsViewModel()
            reopened.load()
            #expect(reopened.rows.first { $0.id == hidden }?.isExposed == false)
            #expect(reopened.rows.first { $0.id != hidden }?.isExposed == true)
        }
        try await clear()
    }

    /// The queries Siri reads through drop the server, while the ones widgets and controls use keep
    /// it — that split is the whole point of the setting.
    @Test func hidingAServerAffectsSiriButNotWidgets() async throws {
        try await clear()
        try await withFakeServers { servers in
            let hidden = servers[0].identifier.rawValue
            SiriServerExposure.setExposed(false, serverId: hidden)

            let provider = ControlEntityProvider(domains: [])
            let siriServers = provider.getEntitiesExposedToSiri().map(\.0.identifier.rawValue)
            let allServers = provider.getEntities().map(\.0.identifier.rawValue)

            #expect(!siriServers.contains(hidden))
            #expect(allServers.contains(hidden))
        }
        try await clear()
    }
}
