@testable import HomeAssistant

import AppIntents
import Foundation
import HAKit
@testable import Shared
import SharedTesting
import Testing

/// The Control Center intents that switch, open or turn things on and off, and the pickers that
/// list the entities each of them can control.
///
/// `.isolatedEnvironment`: servers, the API cache and the database are installed per test; the stub
/// connection resolves each service call before the intent awaits it.
@Suite(.isolatedEnvironment)
struct WidgetControlIntentsTests {
    // MARK: - Switch, cover, fan and light

    @available(iOS 18, *)
    @Test func controlsWithoutAServerSaySo() async throws {
        let connection = try install { _ in .success(.empty) }
        var switchIntent = SwitchIntent()
        switchIntent.entity = .init(id: "x", entityId: "switch.a", serverId: "gone", displayString: "A", iconName: "")
        switchIntent.value = true
        switchIntent.toggle = false
        _ = try await switchIntent.perform()

        var cover = CoverIntent()
        cover.entity = .init(id: "x", entityId: "cover.a", serverId: "gone", displayString: "A", iconName: "")
        cover.value = true
        cover.toggle = false
        _ = try await cover.perform()

        var fan = FanIntent()
        fan.fan = .init(id: "x", entityId: "fan.a", serverId: "gone", displayString: "A", iconName: "")
        fan.value = true
        fan.toggle = false
        _ = try await fan.perform()

        var light = LightIntent()
        light.light = .init(id: "x", entityId: "light.a", serverId: "gone", displayString: "A", iconName: "")
        light.value = true
        light.toggle = false
        _ = try await light.perform()

        #expect(connection.sent.isEmpty)
    }

    /// Each control turns its entity on, off or toggles it through its own domain's services.
    @available(iOS 18, *)
    @Test func controlsCallTheirDomainsServices() async throws {
        let connection = try install { _ in .success(.empty) }

        for (value, toggle) in [(true, false), (false, false), (false, true)] {
            var switchIntent = SwitchIntent()
            switchIntent.entity = .init(
                id: "x",
                entityId: "input_boolean.guest",
                serverId: "control-server",
                displayString: "Guest",
                iconName: ""
            )
            switchIntent.value = value
            switchIntent.toggle = toggle
            _ = try await switchIntent.perform()

            var cover = CoverIntent()
            cover.entity = .init(
                id: "x",
                entityId: "cover.garage",
                serverId: "control-server",
                displayString: "Garage",
                iconName: ""
            )
            cover.value = value
            cover.toggle = toggle
            _ = try await cover.perform()

            var fan = FanIntent()
            fan.fan = .init(
                id: "x",
                entityId: "fan.desk",
                serverId: "control-server",
                displayString: "Desk",
                iconName: ""
            )
            fan.value = value
            fan.toggle = toggle
            _ = try await fan.perform()

            var light = LightIntent()
            light.light = .init(
                id: "x",
                entityId: "light.porch",
                serverId: "control-server",
                displayString: "Porch",
                iconName: ""
            )
            light.value = value
            light.toggle = toggle
            _ = try await light.perform()
        }

        let calls = connection.sent.map { "\($0.data["domain"] ?? "").\($0.data["service"] ?? "")" }
        #expect(calls.count == 12)
        #expect(calls.contains("input_boolean.turn_on"))
        #expect(calls.contains("cover.open_cover"))
        #expect(calls.contains("cover.close_cover"))
        #expect(calls.contains("fan.turn_off"))
        #expect(calls.contains("light.toggle"))
    }

    @available(iOS 18, *)
    @Test func aFailedServiceCallIsReported() async throws {
        _ = try install { _ in .failure(widgetStubUnexpected) }
        var switchIntent = SwitchIntent()
        switchIntent.entity = .init(
            id: "x",
            entityId: "switch.a",
            serverId: "control-server",
            displayString: "A",
            iconName: ""
        )
        switchIntent.value = true
        switchIntent.toggle = false
        await #expect(throws: ShortcutAppIntentError.self) { try await switchIntent.perform() }

        var cover = CoverIntent()
        cover.entity = .init(id: "x", entityId: "cover.a", serverId: "control-server", displayString: "A", iconName: "")
        cover.value = false
        cover.toggle = false
        await #expect(throws: ShortcutAppIntentError.self) { try await cover.perform() }

        var fan = FanIntent()
        fan.fan = .init(id: "x", entityId: "fan.a", serverId: "control-server", displayString: "A", iconName: "")
        fan.value = false
        fan.toggle = true
        await #expect(throws: ShortcutAppIntentError.self) { try await fan.perform() }

        var light = LightIntent()
        light.light = .init(id: "x", entityId: "light.a", serverId: "control-server", displayString: "A", iconName: "")
        light.value = true
        light.toggle = false
        await #expect(throws: ShortcutAppIntentError.self) { try await light.perform() }
    }

    // MARK: - Pickers

    /// Every picker lists its domains' stored entities, one section per server, and searches them.
    @available(iOS 18, *)
    @Test func thePickersListTheirDomainsEntities() async throws {
        _ = try install(entities: [
            ("switch.desk", "Desk switch"), ("input_boolean.guest", "Guest mode"),
            ("cover.garage", "Garage door"), ("fan.ceiling", "Ceiling fan"), ("light.porch", "Porch light"),
            ("scene.movie", "Movie night"), ("automation.wake", "Wake up"),
        ]) { _ in .failure(widgetStubUnexpected) }
        let prefix = "control-server-"

        let switches = try await IntentSwitchAppEntityQuery().suggestedEntities()
        #expect(Set(Self.ids(switches)) == ["\(prefix)switch.desk", "\(prefix)input_boolean.guest"])
        let guest = try await IntentSwitchAppEntityQuery().entities(matching: "guest")
        #expect(Self.ids(guest) == ["\(prefix)input_boolean.guest"])
        let switchById = try await IntentSwitchAppEntityQuery().entities(for: ["\(prefix)switch.desk"])
        #expect(switchById.map(\.displayString) == ["Desk switch"])
        _ = switchById.first?.displayRepresentation

        let covers = try await IntentCoverAppEntityQuery().suggestedEntities()
        #expect(Self.ids(covers) == ["\(prefix)cover.garage"])
        let coverMatch = try await IntentCoverAppEntityQuery().entities(matching: "garage")
        #expect(Self.ids(coverMatch).count == 1)
        let coverById = try await IntentCoverAppEntityQuery().entities(for: ["\(prefix)cover.garage"])
        _ = coverById.first?.displayRepresentation
        #expect(coverById.count == 1)

        let fans = try await IntentFanAppEntityQuery().suggestedEntities()
        #expect(Self.ids(fans) == ["\(prefix)fan.ceiling"])
        let fanMatch = try await IntentFanAppEntityQuery().entities(matching: "nothing")
        #expect(Self.ids(fanMatch).isEmpty)
        let fanById = try await IntentFanAppEntityQuery().entities(for: ["\(prefix)fan.ceiling"])
        _ = fanById.first?.displayRepresentation
        #expect(fanById.count == 1)

        let lights = try await IntentLightAppEntityQuery().suggestedEntities()
        #expect(Self.ids(lights) == ["\(prefix)light.porch"])
        let lightMatch = try await IntentLightAppEntityQuery().entities(matching: "porch")
        #expect(Self.ids(lightMatch).count == 1)
        let lightById = try await IntentLightAppEntityQuery().entities(for: ["\(prefix)light.porch"])
        _ = lightById.first?.displayRepresentation
        #expect(lightById.count == 1)

        let scenes = try await IntentSceneAppEntityQuery().suggestedEntities()
        #expect(Self.ids(scenes) == ["\(prefix)scene.movie"])
        let sceneMatch = try await IntentSceneAppEntityQuery().entities(matching: "movie")
        #expect(Self.ids(sceneMatch).count == 1)
        let sceneById = try await IntentSceneAppEntityQuery().entities(for: ["\(prefix)scene.movie"])
        _ = sceneById.first?.displayRepresentation
        #expect(sceneById.count == 1)

        let automations = try await IntentAutomationAppEntityQuery().suggestedEntities()
        #expect(Self.ids(automations) == ["\(prefix)automation.wake"])
        let automationMatch = try await IntentAutomationAppEntityQuery().entities(matching: "wake")
        #expect(Self.ids(automationMatch).count == 1)
        let automationById = try await IntentAutomationAppEntityQuery().entities(for: ["\(prefix)automation.wake"])
        _ = automationById.first?.displayRepresentation
        #expect(automationById.count == 1)
    }

    // MARK: - Helpers

    private static func ids<T: AppEntity>(_ collection: IntentItemCollection<T>) -> [String] where T.ID == String {
        collection.sections.flatMap(\.items).map(\.value.id)
    }

    /// Registers one server whose API answers through `respond`, with `entities` (entity id, name)
    /// stored for it in a fresh in-memory database.
    private func install(
        entities: [(String, String)] = [],
        _ respond: @escaping WidgetStubConnection.Responder
    ) throws -> WidgetStubConnection {
        let database = try SettingsTestDatabase.make()
        try database.write { db in
            for (entityId, name) in entities {
                try HAAppEntity(
                    id: "control-server-\(entityId)",
                    entityId: entityId,
                    serverId: "control-server",
                    domain: String(entityId.split(separator: ".")[0]),
                    name: name,
                    icon: nil,
                    rawDeviceClass: nil
                ).insert(db)
            }
        }
        Current.database = { database }
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "control-server"), serverInfo: .fake())
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return connection
    }
}
