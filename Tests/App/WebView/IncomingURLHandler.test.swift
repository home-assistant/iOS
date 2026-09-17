import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing
import UIKit

/// Routing of `homeassistant://` deep links. The `camera` link used to open the native camera player;
/// it now lands on the entity's more-info dialog, so links created before the change keep working.
///
/// Serialized because every test swaps globals on `Current`.
@Suite(.serialized)
struct IncomingURLHandlerTests {
    /// Runs the wrapped work without a real `UIApplication`/`ProcessInfo` assertion.
    private final class PassthroughBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            wrapping(nil)
        }
    }

    private final class StubMagicItemProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [:]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            nil
        }

        func getAreaName(for item: MagicItem) -> String? {
            nil
        }
    }

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

    /// Kept non-async so GRDB resolves the synchronous `write` overload.
    private func makeDatabase(shortcutItems: [MagicItem]) throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            try AppIconShortcutConfig(items: shortcutItems).save(db)
        }
        return database
    }

    /// An app icon shortcut whose item is set to "Nothing" ends there: there is no widget to reload
    /// and nothing to open. No server is registered here, so any path that reached for one would
    /// be rejected instead.
    @Test func appIconShortcutSetToNothingEndsQuietly() async throws {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.action = .nothing
        let database = try makeDatabase(shortcutItems: [item])

        let previousServers = Current.servers
        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        let previousRunner = Current.backgroundTask
        Current.servers = FakeServerManager(initial: 0)
        Current.database = { database }
        Current.magicItemProvider = { StubMagicItemProvider() }
        Current.backgroundTask = PassthroughBackgroundTaskRunner()
        defer {
            Current.servers = previousServers
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
            Current.backgroundTask = previousRunner
        }

        let coordinator = MockAppCoordinator()
        let handler = IncomingURLHandler(coordinator: coordinator)
        let shortcut = UIApplicationShortcutItem(
            type: "appIconShortcut.1|entity|light.kitchen",
            localizedTitle: "Kitchen light"
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            handler.handle(shortcutItem: shortcut).pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume()
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }

        #expect(coordinator.openedDeeplinks.isEmpty)
        #expect(coordinator.openedDeeplinksSelectingServer.isEmpty)
    }
}
