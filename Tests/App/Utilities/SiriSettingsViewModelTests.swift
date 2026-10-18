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

    /// Two servers, one hidden: the visible one still has to come through, or the test would pass
    /// on a query that simply returns nothing.
    private func withOneHiddenServer(
        _ body: (_ hidden: String, _ visible: String) async throws -> Void
    ) async throws {
        let previous = Current.servers
        defer { Current.servers = previous }
        let manager = FakeServerManager(initial: 0)
        let hidden = manager.addFake()
        let visible = manager.addFake()
        Current.servers = manager

        for server in [hidden, visible] {
            let id = server.identifier.rawValue
            try await Current.database().write { db in
                try HAAppEntity
                    .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == id)
                    .deleteAll(db)
                for entityId in ["light.kitchen", "lock.front", "climate.hall", "cover.curtain", "script.night"] {
                    try HAAppEntity(
                        id: ServerEntity.uniqueId(serverId: id, entityId: entityId),
                        entityId: entityId,
                        serverId: id,
                        domain: entityId.components(separatedBy: ".").first ?? "",
                        name: entityId,
                        icon: nil,
                        rawDeviceClass: nil,
                        entityCategory: nil,
                        isHidden: nil
                    ).insert(db)
                }
                try AppArea
                    .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == id)
                    .deleteAll(db)
                try AppArea(
                    id: "\(id)-area",
                    serverId: id,
                    areaId: "area",
                    name: "Kitchen",
                    aliases: [],
                    picture: nil,
                    icon: nil,
                    sortOrder: nil,
                    entities: ["light.kitchen", "lock.front", "climate.hall", "cover.curtain", "script.night"],
                    floorId: nil,
                    floorName: nil
                ).insert(db)
            }
        }

        SiriServerExposure.setExposed(false, serverId: hidden.identifier.rawValue)
        try await body(hidden.identifier.rawValue, visible.identifier.rawValue)
        try await clear()
    }

    @Test func theControlQueriesDropTheHiddenServerAndKeepTheOther() async throws {
        try await clear()
        try await withOneHiddenServer { hidden, visible in
            let controllable = try await ControllableEntityAppEntityQuery().suggestedEntities()
                .sections.flatMap(\.items).map(\.value.serverId)
            let locks = try await LockAppEntityQuery().suggestedEntities()
                .sections.flatMap(\.items).map(\.value.serverId)
            let thermostats = try await ThermostatAppEntityQuery().suggestedEntities()
                .sections.flatMap(\.items).map(\.value.serverId)
            let lights = try await DimmableLightAppEntityQuery().suggestedEntities()
                .sections.flatMap(\.items).map(\.value.serverId)
            let covers = try await OpenableEntityAppEntityQuery().suggestedEntities()
                .sections.flatMap(\.items).map(\.value.serverId)

            #expect(!controllable.contains(hidden))
            #expect(controllable.contains(visible))
            #expect(!locks.contains(hidden))
            #expect(locks.contains(visible))
            #expect(!thermostats.contains(hidden))
            #expect(thermostats.contains(visible))
            #expect(!lights.contains(hidden))
            #expect(lights.contains(visible))
            #expect(!covers.contains(hidden))
            #expect(covers.contains(visible))
        }
    }

    @Test func theQuestionAndScriptListsAlsoHonourIt() async throws {
        try await clear()
        try await withOneHiddenServer { hidden, visible in
            let entities = try await HAAppEntityAppIntentEntityQuery().suggestedEntities()
                .sections.flatMap(\.items).map(\.value.serverId)
            let scripts = try await IntentScriptAppEntityQuery().suggestedEntities()
                .sections.flatMap(\.items).map(\.value.serverId)

            #expect(!entities.contains(hidden))
            #expect(entities.contains(visible))
            #expect(!scripts.contains(hidden))
            #expect(scripts.contains(visible))
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
