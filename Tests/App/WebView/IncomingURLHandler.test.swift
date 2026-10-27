import CoreSpotlight
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Routing of `homeassistant://` deep links. The `camera` link opens the native camera player for a
/// camera, and the more-info dialog for any other entity a link made before it was reinstated names.
@Suite(.serialized)
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

    /// What the handler asked the camera player to show.
    private struct CameraPresentation: Equatable {
        let entityId: String
        let serverId: String?
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

    @Test func cameraDeeplinkOpensTheCameraPlayerInsteadOfTheFrontend() throws {
        try withFakeServer { server, coordinator, handler in
            var presented: [CameraPresentation] = []
            handler.presentCamera = { presented.append(.init(entityId: $0, serverId: $1)) }
            let url = try #require(AppConstants.openCameraDeeplinkURL(
                entityId: "camera.porch",
                serverId: server.identifier.rawValue
            ))

            #expect(handler.handle(url: url))

            #expect(presented == [.init(entityId: "camera.porch", serverId: server.identifier.rawValue)])
            #expect(coordinator.openedDeeplinks.isEmpty)
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test func cameraDeeplinkForAnotherEntityOpensTheMoreInfoDialog() throws {
        try withFakeServer { server, coordinator, handler in
            var presented: [CameraPresentation] = []
            handler.presentCamera = { presented.append(.init(entityId: $0, serverId: $1)) }
            let url = try #require(AppConstants.openCameraDeeplinkURL(
                entityId: "light.porch",
                serverId: server.identifier.rawValue
            ))

            #expect(handler.handle(url: url))

            #expect(presented.isEmpty)
            let opened = try #require(coordinator.openedDeeplinks.first)
            #expect(opened.server.identifier == server.identifier)
            #expect(opened.urlString.contains("\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=light.porch"))
            #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test(arguments: [
        (entityId: "camera.porch", opensMoreInfo: false),
        (entityId: "light.porch", opensMoreInfo: true),
    ])
    func spotlightTapOpensCamerasInThePlayerAndEverythingElseInMoreInfo(
        entityId: String,
        opensMoreInfo: Bool
    ) throws {
        try withFakeServer { server, coordinator, handler in
            let database = try DatabaseQueue(path: ":memory:")
            try HAppEntityTable().createIfNeeded(database: database)
            let uniqueId = ServerEntity.uniqueId(serverId: server.identifier.rawValue, entityId: entityId)
            try database.write { db in
                try HAAppEntity(
                    id: uniqueId,
                    entityId: entityId,
                    serverId: server.identifier.rawValue,
                    domain: entityId.components(separatedBy: ".").first ?? "",
                    name: "Porch",
                    icon: nil,
                    rawDeviceClass: nil
                ).insert(db)
            }
            let previousDatabase = Current.database
            Current.database = { database }
            defer { Current.database = previousDatabase }

            var presented: [CameraPresentation] = []
            handler.presentCamera = { presented.append(.init(entityId: $0, serverId: $1)) }
            let activity = NSUserActivity(activityType: CSSearchableItemActionType)
            activity.userInfo = [CSSearchableItemActivityIdentifier: uniqueId]

            #expect(handler.handle(userActivity: activity))
            #expect(coordinator.openedDeeplinks.isEmpty == !opensMoreInfo)
            #expect(presented == (opensMoreInfo ? [] : [.init(
                entityId: entityId,
                serverId: server.identifier.rawValue
            )]))
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
