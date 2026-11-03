import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing

/// The REST reads the widgets and controls make through `ControlEntityProvider`: an entity's state,
/// its raw state, its attributes, and what each returns when the server can't be asked or answers
/// with something unexpected.
///
/// `.isolatedEnvironment`: the server, API cache and database are installed per test, and the stub
/// connection answers on the test's own task.
@Suite(.isolatedEnvironment)
struct ControlEntityProviderRequestsTests {
    private let provider = ControlEntityProvider(domains: [.light, .binarySensor])

    @Test func theCurrentStateIsReadFromTheStatesEndpoint() async throws {
        let (server, connection) = try install { request in
            request.type.command == "states/light.kitchen"
                ? .success(HAData(value: ["state": "on"]))
                : .failure(Self.unexpected)
        }
        let state = try await provider.currentState(serverId: server.identifier.rawValue, entityId: "light.kitchen")
        #expect(state == "on")
        let failed = try await provider.currentState(serverId: server.identifier.rawValue, entityId: "light.other")
        #expect(failed == nil)
        let unknown = try await provider.currentState(serverId: "gone", entityId: "light.kitchen")
        #expect(unknown == nil)
        #expect(connection.sentCommands == ["states/light.kitchen", "states/light.other"])
    }

    @Test func attributesAndRawStatesReportWhatCameBack() async throws {
        let (server, _) = try install { request in
            switch request.type.command {
            case "states/sensor.ok":
                .success(HAData(value: ["state": "21.456", "attributes": ["unit_of_measurement": "°C"]]))
            case "states/sensor.bare":
                .success(HAData(value: ["state": "1"]))
            case "states/sensor.list":
                .success(HAData(value: ["not", "a", "state"]))
            default:
                .failure(Self.unexpected)
            }
        }

        let attributes = await provider.attributes(server: server, entityId: "sensor.ok")
        #expect(attributes?["unit_of_measurement"] as? String == "°C")
        let badAttributes = await provider.attributes(server: server, entityId: "sensor.list")
        #expect(badAttributes == nil)
        let failedAttributes = await provider.attributes(server: server, entityId: "sensor.failing")
        #expect(failedAttributes == nil)

        let raw = await provider.rawState(server: server, entityId: "sensor.ok")
        #expect(raw?.state == "21.456")
        let bare = await provider.rawState(server: server, entityId: "sensor.bare")
        #expect(bare?.attributes.isEmpty == true)
        let badRaw = await provider.rawState(server: server, entityId: "sensor.list")
        #expect(badRaw == nil)
        let failedRaw = await provider.rawState(server: server, entityId: "sensor.failing")
        #expect(failedRaw == nil)
    }

    @Test func aServerWithoutAnyURLIsNeverAsked() async throws {
        let database = try DatabaseQueue()
        Current.database = { database }
        let offline = Server.fake { info in info.connection.set(address: nil, for: .external) }
        let attributes = await provider.attributes(server: offline, entityId: "light.a")
        let raw = await provider.rawState(server: offline, entityId: "light.a")
        let state = await provider.state(server: offline, entityId: "light.a")
        #expect(attributes == nil)
        #expect(raw == nil)
        #expect(state == nil)
    }

    /// A device-class entity reads the way the frontend words it ("Open", not "On"), and an answer
    /// that isn't an entity state, or a failed request, gives no state.
    @Test func statesAreBuiltFromTheResponse() async throws {
        let (server, _) = try install { request in
            switch request.type.command {
            case "states/binary_sensor.door":
                .success(HAData(value: ["state": "on", "attributes": ["device_class": "door"]]))
            case "states/light.kitchen":
                .success(HAData(value: [
                    "state": "on",
                    "attributes": ["rgb_color": [255, 0, 0], "friendly_name": "Kitchen"],
                ]))
            case "states/group.lights":
                .success(HAData(value: ["state": "off", "attributes": ["entity_id": ["light.a", "light.b"]]]))
            case "states/sensor.list":
                .success(HAData(value: ["not", "a", "state"]))
            default:
                .failure(Self.unexpected)
            }
        }

        let door = try await #require(provider.state(server: server, entityId: "binary_sensor.door"))
        #expect(door.rawState == "on")
        #expect(door.deviceClass == "door")
        #expect(door.unitOfMeasurement == nil)
        #expect(!door.value.isEmpty)

        let light = try await #require(provider.state(server: server, entityId: "light.kitchen"))
        #expect(light.liveColor != nil)

        let group = try await #require(provider.state(server: server, entityId: "group.lights"))
        #expect(group.groupMemberDomain == "light")

        let list = await provider.state(server: server, entityId: "sensor.list")
        #expect(list == nil)
        let failed = await provider.state(server: server, entityId: "sensor.failing")
        #expect(failed == nil)
    }

    /// A state fetch whose server never answers gives up when its task is cancelled instead of
    /// waiting forever.
    @Test func aCancelledStateFetchGivesUp() async throws {
        let (server, connection) = try install { _ in nil }
        let finished = Flag()
        let task = Task {
            let state = await provider.state(server: server, entityId: "light.silent")
            finished.set()
            return state
        }
        let sent = Date().addingTimeInterval(10)
        while connection.sentCommands.isEmpty, Date() < sent {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        task.cancel()

        let deadline = Date().addingTimeInterval(10)
        while !finished.isSet, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try #require(finished.isSet)
        let state = await task.value
        #expect(state == nil)
        #expect(connection.cancellations == 1)
    }

    @Test func entitiesThatCannotBeReadAreSkipped() throws {
        let servers = FakeServerManager()
        _ = servers.addFake()
        Current.servers = servers
        let database = try DatabaseQueue()
        Current.database = { database }
        #expect(provider.getEntities().isEmpty)
    }

    // MARK: - Helpers

    private static let unexpected: HAError = .internal(debugDescription: "unexpected request")

    private func install(
        _ respond: @escaping RespondingHAConnection.Responder
    ) throws -> (Server, RespondingHAConnection) {
        let database = try DatabaseQueue()
        Current.database = { database }
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "control-provider"), serverInfo: .fake())
        Current.servers = servers
        let connection = RespondingHAConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }

    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        var isSet: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func set() {
            lock.lock()
            value = true
            lock.unlock()
        }
    }
}
