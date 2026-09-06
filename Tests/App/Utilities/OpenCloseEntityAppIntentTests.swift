import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers the spoken open and close command: the service it picks per direction, the sentence it
/// reads back, and the two ways it can refuse.
struct OpenCloseEntityAppIntentTests {
    private static func cover(serverId: String, entityId: String = "cover.curtain") -> OpenableEntityAppEntity {
        OpenableEntityAppEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            serverName: "Home",
            areaName: "Living room",
            displayString: "Curtain",
            iconName: "mdi:curtains"
        )
    }

    /// Runs `perform()` against a mocked connection, answering the one request it sends.
    ///
    /// The intent is async while the connection records requests synchronously, so the call is
    /// started first and the request answered once it lands, rather than the other way around.
    private func perform(
        _ intent: OpenCloseEntityAppIntent,
        connection: HAMockConnection
    ) async throws -> (dialog: String?, request: HARequest?) {
        let task = Task { try await intent.perform() }
        var waited = 0
        while connection.pendingRequests.isEmpty, waited < 200 {
            try await Task.sleep(nanoseconds: 5_000_000)
            waited += 1
        }
        let request = connection.pendingRequests.first?.request
        for pending in connection.pendingRequests {
            pending.completion(.success(.empty))
        }
        let result = try await task.value
        return (result.dialog.map { "\($0)" }, request)
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

    @Test func openCallsOpenCover() async throws {
        try await withMockedServer { server, connection in
            let intent = OpenCloseEntityAppIntent()
            intent.action = .open
            intent.entity = Self.cover(serverId: server.identifier.rawValue)

            let (dialog, request) = try await perform(intent, connection: connection)
            #expect(request?.data["domain"] as? String == "cover")
            #expect(request?.data["service"] as? String == "open_cover")
            #expect(dialog?.contains("Curtain") == true)
        }
    }

    @Test func closeCallsCloseCover() async throws {
        try await withMockedServer { server, connection in
            let intent = OpenCloseEntityAppIntent()
            intent.action = .close
            intent.entity = Self.cover(serverId: server.identifier.rawValue)

            let (_, request) = try await perform(intent, connection: connection)
            #expect(request?.data["service"] as? String == "close_cover")
        }
    }

    @Test func refusesWhenTheServerIsGone() async throws {
        let previous = Current.servers
        defer { Current.servers = previous }
        Current.servers = FakeServerManager(initial: 0)

        let intent = OpenCloseEntityAppIntent()
        intent.action = .open
        intent.entity = Self.cover(serverId: "missing")

        await #expect(throws: ShortcutAppIntentError.self) {
            _ = try await intent.perform()
        }
    }

    /// The entity id is what names the domain, so one that isn't openable has no services to call.
    @Test func refusesADomainThatDoesNotOpen() async throws {
        try await withMockedServer { server, _ in
            let intent = OpenCloseEntityAppIntent()
            intent.action = .open
            intent.entity = Self.cover(serverId: server.identifier.rawValue, entityId: "sensor.humidity")

            await #expect(throws: ShortcutAppIntentError.self) {
                _ = try await intent.perform()
            }
        }
    }

    @Test func everyActionReadsBack() {
        for action in [OpenCloseActionAppEnum.open, .close] {
            #expect(OpenCloseActionAppEnum.caseDisplayRepresentations[action] != nil)
        }
    }
}
