import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Routing of `homeassistant://` deep links. The `camera` link used to open the native camera player;
/// it now lands on the entity's more-info dialog, so links created before the change keep working.
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

    private func withAppIconShortcutConfig(item: MagicItem, _ body: () throws -> Void) throws {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            try AppIconShortcutConfig(items: [item]).save(db)
        }

        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try body()
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

    @Test func settingsDeeplinkShowsAppSettings() throws {
        try withFakeServer { _, coordinator, handler in
            let url = try #require(URL(string: "\(AppConstants.deeplinkURL.absoluteString)settings"))

            #expect(handler.handle(url: url))

            #expect(coordinator.showSettingsCalled)
            #expect(!coordinator.showSettingsPushedOntoNavigationStack)
            #expect(coordinator.openedDeeplinks.isEmpty)
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test func appIconShortcutNavigateStripsLeadingSlash() throws {
        try withFakeServer { server, coordinator, handler in
            let item = MagicItem(
                id: "light.input_test",
                serverId: server.identifier.rawValue,
                type: .entity,
                action: .navigate("/ios-input-test/0")
            )

            try withAppIconShortcutConfig(item: item) {
                let shortcutItem = UIApplicationShortcutItem(
                    type: "appIconShortcut.\(item.serverId)|\(item.type.rawValue)|\(item.id)",
                    localizedTitle: "Input test"
                )

                try handler.handle(shortcutItem: shortcutItem).wait()

                let routedURLString = try #require(coordinator.openedDeeplinksSelectingServer.first)
                let components = try #require(URLComponents(string: routedURLString))
                #expect(components.path == "/ios-input-test/0")
                #expect(coordinator.openedDeeplinks.isEmpty)
            }
        }
    }
}
