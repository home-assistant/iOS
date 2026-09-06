import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers the card the control commands show once they have changed something.
struct ControlResultSnippetTests {
    private static func light(serverId: String) -> ControllableEntityAppEntity {
        ControllableEntityAppEntity(
            id: "\(serverId)-light.kitchen",
            entityId: "light.kitchen",
            serverId: serverId,
            serverName: "Home",
            areaName: "Kitchen",
            deviceName: "Ceiling",
            floorName: "Ground floor",
            displayString: "Ceiling",
            iconName: "mdi:ceiling-light"
        )
    }

    private static func stateResponse(_ state: String) -> HAData {
        .dictionary([
            "entity_id": "light.kitchen",
            "state": state,
            "last_changed": "2026-09-06T10:00:00.000000+00:00",
            "last_updated": "2026-09-06T10:00:00.000000+00:00",
            "attributes": ["friendly_name": "Ceiling"],
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

    /// Answers the state read the card makes, once it lands.
    private func answer(_ connection: HAMockConnection, with data: HAData) async throws {
        var waited = 0
        while connection.pendingRequests.isEmpty, waited < 200 {
            try await Task.sleep(nanoseconds: 5_000_000)
            waited += 1
        }
        for pending in connection.pendingRequests {
            pending.completion(.success(data))
        }
    }

    @Test func describesTheEntityAsItStandsAfterwards() async throws {
        try await withMockedServer { server, connection in
            let entity = Self.light(serverId: server.identifier.rawValue)
            let task = Task {
                await ControlResultSnippet.state(
                    of: entity,
                    serverId: entity.serverId,
                    iconName: entity.iconName
                )
            }
            try await answer(connection, with: Self.stateResponse("on"))
            let state = await task.value

            #expect(state?.name == "Ceiling")
            #expect(state?.entityId == "light.kitchen")
            #expect(state?.state == "on")
            #expect(state?.isActive == true)
            #expect(state?.iconName == "mdi:ceiling-light")
            #expect(state?.areaName == "Kitchen")
            #expect(state?.serverName == server.info.name)
        }
    }

    /// The command already changed something by the time the card is built, so a failed read back
    /// drops the card rather than failing the command.
    @Test func offersNoCardWhenTheServerIsGone() async throws {
        let previous = Current.servers
        defer { Current.servers = previous }
        Current.servers = FakeServerManager(initial: 0)

        let entity = Self.light(serverId: "missing")
        let state = await ControlResultSnippet.state(
            of: entity,
            serverId: entity.serverId,
            iconName: entity.iconName
        )
        #expect(state == nil)
    }

    /// The card is tinted Home Assistant blue rather than the amber a lit light carries in the
    /// frontend palette, which is the colour Apple's Home app uses.
    @MainActor @Test func theCardBuildsItsBody() {
        var state = HAEntityStateAppEntity()
        state.name = "Ceiling"
        state.formattedState = "On"
        state.iconName = "mdi:ceiling-light"
        state.areaName = "Kitchen"
        let view = ControlResultSnippetView(state: state)
        #expect(!String(describing: view.body).isEmpty)
    }
}
