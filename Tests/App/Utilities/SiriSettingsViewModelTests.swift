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

/// Every list Siri reads through honours the opt-out. Each query is checked on its own, so a
/// regression names the one that stopped filtering rather than just "Siri sees too much".
@MainActor
struct SiriExposureAcrossQueriesTests {
    private func clear() async throws {
        try await Current.database().write { db in
            _ = try SiriServerExposure.deleteAll(db)
        }
    }

    private func withHiddenServer(_ body: (String) async throws -> Void) async throws {
        let previous = Current.servers
        defer { Current.servers = previous }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager
        let serverId = server.identifier.rawValue
        SiriServerExposure.setExposed(false, serverId: serverId)
        try await body(serverId)
        try await clear()
    }

    @Test func theControlQueriesOfferNothingFromAHiddenServer() async throws {
        try await clear()
        try await withHiddenServer { _ in
            let controllable = try await ControllableEntityAppEntityQuery().suggestedEntities()
            let locks = try await LockAppEntityQuery().suggestedEntities()
            let thermostats = try await ThermostatAppEntityQuery().suggestedEntities()
            let lights = try await DimmableLightAppEntityQuery().suggestedEntities()
            let covers = try await OpenableEntityAppEntityQuery().suggestedEntities()

            #expect(controllable.sections.flatMap(\.items).isEmpty)
            #expect(locks.sections.flatMap(\.items).isEmpty)
            #expect(thermostats.sections.flatMap(\.items).isEmpty)
            #expect(lights.sections.flatMap(\.items).isEmpty)
            #expect(covers.sections.flatMap(\.items).isEmpty)
        }
    }

    @Test func theQuestionAndScriptListsAlsoHonourIt() async throws {
        try await clear()
        try await withHiddenServer { _ in
            let entities = try await HAAppEntityAppIntentEntityQuery().suggestedEntities()
            let scripts = try await IntentScriptAppEntityQuery().suggestedEntities()

            #expect(entities.sections.flatMap(\.items).isEmpty)
            #expect(scripts.sections.flatMap(\.items).isEmpty)
        }
    }
}

/// The screen itself draws, and its rows carry what the model holds.
@MainActor
struct SiriSettingsViewTests {
    @Test func theScreenBuildsItsBody() {
        #expect(!String(describing: SiriSettingsView().body).isEmpty)
    }

    @Test func theScreenOffersItsSearchEntries() {
        #expect(!SiriSettingsView.settingsSearchEntries.isEmpty)
    }
}
