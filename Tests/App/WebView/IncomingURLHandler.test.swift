@testable import HomeAssistant
@testable import Shared
import Testing

/// The `camera` deep link used to open the native camera player; it now lands on the entity's
/// more-info dialog, so links created before the change keep working.
struct IncomingURLHandlerTests {
    private func withFakeServer(_ body: (Server, MockAppCoordinator, IncomingURLHandler) throws -> Void) throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager

        let coordinator = MockAppCoordinator()
        let handler = IncomingURLHandler(coordinator: coordinator)
        try body(server, coordinator, handler)
    }

    @Test func cameraDeeplinkOpensTheMoreInfoDialog() throws {
        try withFakeServer { server, coordinator, handler in
            let url = try #require(URL(
                string: "\(AppConstants.deeplinkURL.absoluteString)camera/?entityId=camera.porch&serverId=\(server.identifier.rawValue)"
            ))

            #expect(handler.handle(url: url))

            let opened = try #require(coordinator.openedDeeplinks.first)
            #expect(opened.server.identifier == server.identifier)
            #expect(opened.urlString.contains("\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=camera.porch"))
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test func cameraDeeplinkWithoutEntityIsRejected() throws {
        try withFakeServer { server, coordinator, handler in
            let url = try #require(URL(
                string: "\(AppConstants.deeplinkURL.absoluteString)camera/?serverId=\(server.identifier.rawValue)"
            ))

            #expect(!handler.handle(url: url))
            #expect(coordinator.openedDeeplinks.isEmpty)
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }
}
