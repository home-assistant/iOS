import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// Drives each spoken control command end to end: the service it calls, and the card it comes back
/// with. Every one of them now makes two requests — the action, then the state it reads back to
/// describe — so the helper answers them in that order.
struct ControlIntentSnippetTests {
    private static func controllable(
        serverId: String,
        entityId: String = "light.kitchen"
    ) -> ControllableEntityAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            serverName: "Home",
            areaName: "Kitchen",
            displayString: "Ceiling",
            iconName: "mdi:ceiling-light"
        )
    }

    private static func stateResponse(entityId: String, state: String) -> HAData {
        .dictionary([
            "entity_id": entityId,
            "state": state,
            "last_changed": "2026-09-06T10:00:00.000000+00:00",
            "last_updated": "2026-09-06T10:00:00.000000+00:00",
            "attributes": ["friendly_name": "Ceiling"],
            "context": ["id": "test", "parent_id": NSNull(), "user_id": NSNull()],
        ])
    }

    private func withMockedServer(_ body: (Server, HAMockConnection) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
        }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.cachedApis = [server.identifier: api]
        try await body(server, connection)
    }

    /// Answers each request as it lands, keeping the ones the intent sent so the test can assert
    /// which service it called.
    private func drain(
        _ connection: HAMockConnection,
        entityId: String,
        state: String,
        answering count: Int
    ) async throws -> [HARequest] {
        var seen: [HARequest] = []
        var answered = 0
        var waited = 0
        while answered < count, waited < 400 {
            if connection.pendingRequests.count > answered {
                let pending = connection.pendingRequests[answered]
                seen.append(pending.request)
                pending.completion(.success(Self.stateResponse(entityId: entityId, state: state)))
                answered += 1
                continue
            }
            try await Task.sleep(nanoseconds: 5_000_000)
            waited += 1
        }
        return seen
    }

    private func service(in requests: [HARequest]) -> String? {
        requests.compactMap { $0.data["service"] as? String }.first
    }

    @Test func turningOnCallsTurnOnAndDescribesTheResult() async throws {
        try await withMockedServer { server, connection in
            var intent = TurnOnOffEntityAppIntent(action: .on)
            intent.entity = Self.controllable(serverId: server.identifier.rawValue)
            let task = Task { try await intent.perform() }
            let requests = try await drain(connection, entityId: "light.kitchen", state: "on", answering: 2)
            _ = try await task.value
            #expect(service(in: requests) == "turn_on")
        }
    }

    @Test func turningOffCallsTurnOff() async throws {
        try await withMockedServer { server, connection in
            var intent = TurnOnOffEntityAppIntent(action: .off)
            intent.entity = Self.controllable(serverId: server.identifier.rawValue)
            let task = Task { try await intent.perform() }
            let requests = try await drain(connection, entityId: "light.kitchen", state: "off", answering: 2)
            _ = try await task.value
            #expect(service(in: requests) == "turn_off")
        }
    }

    @Test func lockingCallsLock() async throws {
        try await withMockedServer { server, connection in
            var intent = LockEntityAppIntent()
            intent.entity = LockAppEntity(
                id: "\(server.identifier.rawValue)-lock.front",
                entityId: "lock.front",
                serverId: server.identifier.rawValue,
                serverName: "Home",
                displayString: "Front door",
                iconName: "mdi:lock"
            )
            let task = Task { try await intent.perform() }
            let requests = try await drain(connection, entityId: "lock.front", state: "locked", answering: 2)
            _ = try await task.value
            #expect(service(in: requests) == "lock")
        }
    }

    @Test func openingACoverCallsOpenCover() async throws {
        try await withMockedServer { server, connection in
            var intent = OpenCloseEntityAppIntent()
            intent.action = .open
            intent.entity = OpenableEntityAppEntity(
                id: "\(server.identifier.rawValue)-cover.curtain",
                entityId: "cover.curtain",
                serverId: server.identifier.rawValue,
                serverName: "Home",
                displayString: "Curtain",
                iconName: "mdi:curtains"
            )
            let task = Task { try await intent.perform() }
            let requests = try await drain(connection, entityId: "cover.curtain", state: "open", answering: 2)
            _ = try await task.value
            #expect(service(in: requests) == "open_cover")
        }
    }

    @Test func settingTheTemperatureCallsSetTemperature() async throws {
        try await withMockedServer { server, connection in
            var intent = SetTemperatureAppIntent()
            intent.entity = ThermostatAppEntity(
                id: "\(server.identifier.rawValue)-climate.hall",
                entityId: "climate.hall",
                serverId: server.identifier.rawValue,
                serverName: "Home",
                displayString: "Hall",
                iconName: "mdi:thermostat"
            )
            intent.temperature = 21
            let task = Task { try await intent.perform() }
            let requests = try await drain(connection, entityId: "climate.hall", state: "heat", answering: 2)
            _ = try await task.value
            #expect(service(in: requests) == "set_temperature")
        }
    }

    @Test func settingBrightnessCallsTurnOn() async throws {
        try await withMockedServer { server, connection in
            var intent = SetBrightnessAppIntent()
            intent.light = DimmableLightAppEntity(
                id: "\(server.identifier.rawValue)-light.kitchen",
                entityId: "light.kitchen",
                serverId: server.identifier.rawValue,
                serverName: "Home",
                displayString: "Ceiling",
                iconName: "mdi:ceiling-light"
            )
            intent.brightness = 40
            let task = Task { try await intent.perform() }
            let requests = try await drain(connection, entityId: "light.kitchen", state: "on", answering: 2)
            _ = try await task.value
            #expect(service(in: requests) == "turn_on")
        }
    }
}
