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
            // HAEntity requires a context; without it the decode throws and no card is built.
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

    /// Answers each state read the card makes, in order, until they stop coming. The last state
    /// given answers every read after it, which is how a device that ignores the command behaves.
    private func answerReads(_ connection: HAMockConnection, with states: [String]) async throws {
        var answered = 0
        var idle = 0
        // The card waits a quarter second between reads, so a longer silence than that means it
        // has stopped asking.
        while idle < 120 {
            guard connection.pendingRequests.count > answered else {
                try await Task.sleep(nanoseconds: 5_000_000)
                idle += 1
                continue
            }
            let state = states[min(answered, states.count - 1)]
            connection.pendingRequests[answered].completion(.success(Self.stateResponse(state)))
            answered += 1
            idle = 0
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

    /// Home Assistant answers a service call before the device has reported back, so the first read
    /// still says the light is off. The card waits for the state the action asked for rather than
    /// drawing the one it replaced.
    @Test func waitsForTheStateTheActionAskedFor() async throws {
        try await withMockedServer { server, connection in
            let entity = Self.light(serverId: server.identifier.rawValue)
            let task = Task {
                await ControlResultSnippet.state(
                    of: entity,
                    serverId: entity.serverId,
                    iconName: entity.iconName,
                    settlingOn: ["on"]
                )
            }
            try await answerReads(connection, with: ["off", "on"])
            let state = await task.value

            #expect(state?.state == "on")
            #expect(state?.isActive == true)
        }
    }

    /// A device that ignores the command is reported as it is: the card gives up on the state it
    /// was waiting for rather than claiming the light came on.
    @Test func reportsTheStateADeviceThatRefusesIsLeftIn() async throws {
        try await withMockedServer { server, connection in
            let entity = Self.light(serverId: server.identifier.rawValue)
            let task = Task {
                await ControlResultSnippet.state(
                    of: entity,
                    serverId: entity.serverId,
                    iconName: entity.iconName,
                    settlingOn: ["on"]
                )
            }
            try await answerReads(connection, with: ["off"])
            let state = await task.value

            #expect(state?.state == "off")
            #expect(state?.isActive == false)
        }
    }

    /// A curtain reads `closing` for as long as it travels, which outlasts any card. That state
    /// already proves the command landed, so the card shows it rather than waiting out the deadline
    /// on `closed` and reporting the curtain as still open.
    @Test func takesAMovingCoverAsProofTheCommandLanded() async throws {
        try await withMockedServer { server, connection in
            let entity = Self.light(serverId: server.identifier.rawValue)
            let task = Task {
                await ControlResultSnippet.state(
                    of: entity,
                    serverId: entity.serverId,
                    iconName: entity.iconName,
                    settlingOn: Domain.cover.statesAfter(.closeCover)
                )
            }
            try await answerReads(connection, with: ["open", "closing"])
            let state = await task.value

            #expect(state?.state == "closing")
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

    /// The icon falls back twice: a Material Design name, then an SF Symbol name, then a symbol
    /// that stands in for both. Each branch draws a different row.
    @MainActor @Test func theCardDrawsEveryIconKind() {
        for iconName in ["mdi:ceiling-light", "power.circle.fill", "not-an-icon-anywhere"] {
            var state = HAEntityStateAppEntity()
            state.name = "Ceiling"
            state.formattedState = "On"
            state.iconName = iconName
            state.areaName = "Kitchen"
            let view = ControlResultSnippetView(state: state)
            #expect(!String(describing: view.body).isEmpty, "no body for \(iconName)")
        }
    }

    /// An entity with no room, device or floor has no second line, so the card drops it rather
    /// than drawing an empty one.
    @MainActor @Test func theCardOmitsAnEmptyContextLine() {
        var state = HAEntityStateAppEntity()
        state.name = "Ceiling"
        state.formattedState = "On"
        state.iconName = "mdi:ceiling-light"
        let view = ControlResultSnippetView(state: state)
        #expect(!String(describing: view.body).isEmpty)
    }
}
