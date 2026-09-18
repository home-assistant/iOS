import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers which server a camera snapshot is taken from.
@Suite(.serialized)
struct GetCameraSnapshotAppIntentTests {
    /// With several servers set up an unknown identifier resolves to nothing, so a camera belonging
    /// to a different server than the one picked is refused rather than snapshotted from the wrong
    /// place.
    @Test func refusesACameraBelongingToAnotherServer() async throws {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
        }

        let manager = FakeServerManager(initial: 2)
        Current.servers = manager
        Current.cachedApis = manager.all.reduce(into: [Identifier<Server>: HomeAssistantAPI]()) { apis, server in
            let api = HomeAssistantAPI(server: server)
            api.connection = HAMockConnection()
            apis[server.identifier] = api
        }

        let intent = GetCameraSnapshotAppIntent()
        intent.server = IntentServerAppEntity(from: manager.all[0])
        intent.camera = IntentCameraEntity(
            serverId: manager.all[1].identifier.rawValue,
            entityId: "camera.front_door",
            displayName: "Front door"
        )

        await #expect(throws: ShortcutAppIntentError.self) {
            _ = try await intent.perform()
        }
    }
}
