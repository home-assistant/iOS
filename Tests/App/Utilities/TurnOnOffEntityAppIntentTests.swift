import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// One intent now switches both ways, so each direction is checked for the service it sends.
struct TurnOnOffEntityAppIntentTests {
    private static func entity(serverId: String, entityId: String = "light.kitchen") -> ControllableEntityAppEntity {
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

    private func serviceCalled(
        _ intent: TurnOnOffEntityAppIntent,
        connection: HAMockConnection
    ) async throws -> String? {
        let task = Task { try await intent.perform() }
        var waited = 0
        while connection.pendingRequests.isEmpty, waited < 300 {
            try await Task.sleep(nanoseconds: 5_000_000)
            waited += 1
        }
        let request = connection.pendingRequests.first?.request
        for pending in connection.pendingRequests {
            pending.completion(.success(.empty))
        }
        _ = try? await task.value
        return request?.data["service"] as? String
    }

    @Test func onSendsTurnOn() async throws {
        try await withMockedServer { server, connection in
            var intent = TurnOnOffEntityAppIntent(action: .on)
            intent.entity = Self.entity(serverId: server.identifier.rawValue)
            let service = try await serviceCalled(intent, connection: connection)
            #expect(service == "turn_on")
        }
    }

    @Test func offSendsTurnOff() async throws {
        try await withMockedServer { server, connection in
            var intent = TurnOnOffEntityAppIntent(action: .off)
            intent.entity = Self.entity(serverId: server.identifier.rawValue)
            let service = try await serviceCalled(intent, connection: connection)
            #expect(service == "turn_off")
        }
    }

    /// The service still comes from the domain, so the same intent opens a cover.
    @Test func onOpensACover() async throws {
        try await withMockedServer { server, connection in
            var intent = TurnOnOffEntityAppIntent(action: .on)
            intent.entity = Self.entity(serverId: server.identifier.rawValue, entityId: "cover.curtain")
            let service = try await serviceCalled(intent, connection: connection)
            #expect(service == "open_cover")
        }
    }

    @Test func eachDirectionMapsToTheRunner() {
        #expect(TurnOnOffActionAppEnum.on.runnerAction == .turnOn)
        #expect(TurnOnOffActionAppEnum.off.runnerAction == .turnOff)
        #expect(TurnOnOffActionAppEnum.toggle.runnerAction == .toggle)
        #expect(TurnOnOffActionAppEnum.caseDisplayRepresentations.count == 3)
    }

    @Test func theSummaryBuilds() {
        #expect(!String(describing: TurnOnOffEntityAppIntent.parameterSummary).isEmpty)
    }
}
