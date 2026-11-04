import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// The native sidebar fed from a mocked connection: the panels, user and preferences it subscribes
/// to, the fallback for cores without the user data subscription, the notification badge, and the
/// edits it saves back.
@Suite(.sharedState)
@MainActor
struct MacSidebarViewModelConnectionTests {
    private struct Context {
        let viewModel: MacSidebarViewModel
        let connection: HAMockConnection
    }

    private func withViewModel(_ body: (Context) async throws -> Void) async throws {
        let previousCachedApis = Current.cachedApis
        defer { Current.cachedApis = previousCachedApis }
        let suiteName = "MacSidebarViewModelConnectionTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let server = Server.fake()
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)

        let viewModel = MacSidebarViewModel(
            server: server,
            overlayState: WebFrontendOverlayState(),
            snapshotStore: MacSidebarSnapshotStore(userDefaults: userDefaults)
        )
        try await body(Context(viewModel: viewModel, connection: connection))
        viewModel.stop()
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private static let panels: [String: Any] = [
        "lovelace": ["component_name": "lovelace", "url_path": "lovelace", "title": "Overview"],
        "energy": ["component_name": "energy", "url_path": "energy", "title": "Energy", "icon": "mdi:lightning-bolt"],
        "map": ["component_name": "map", "url_path": "map", "title": "Map", "icon": "mdi:map"],
        "config": [
            "component_name": "config",
            "url_path": "config",
            "title": "Settings",
            "icon": "mdi:cog",
            "require_admin": true,
        ],
    ]

    /// Answers every request sent so far the way a core would.
    private func answerRequests(on connection: HAMockConnection, from answered: inout Int) {
        while answered < connection.pendingRequests.count {
            let pending = connection.pendingRequests[answered]
            answered += 1
            let data: HAData = switch pending.request.type.command {
            case "get_panels":
                .dictionary(Self.panels)
            case "auth/current_user":
                .dictionary(["id": "user", "name": "Jane", "is_owner": true, "is_admin": true])
            case "frontend/get_user_data":
                .dictionary(["value": [
                    "panelOrder": ["energy", "lovelace"],
                    "hiddenPanels": ["map"],
                    FrontendDefaultPanelData.defaultPanelKey: "energy",
                ]])
            case "frontend/get_system_data":
                .dictionary(["value": [FrontendDefaultPanelData.defaultPanelKey: "lovelace"]])
            default:
                .empty
            }
            pending.completion(.success(data))
        }
    }

    @Test func loadsThePanelsUserAndPreferencesFromTheServer() async throws {
        try await withViewModel { context in
            context.viewModel.start()
            // A second start keeps the subscriptions it already has.
            context.viewModel.start()

            var answered = 0
            answerRequests(on: context.connection, from: &answered)

            // A core without `frontend/subscribe_user_data` gets the one-off fetch instead.
            for subscription in context.connection.pendingSubscriptions {
                switch subscription.request.type.command {
                case "frontend/subscribe_user_data":
                    subscription.initiated(.failure(.internal(debugDescription: "unknown_command")))
                case "persistent_notification/subscribe":
                    subscription.initiated(.success(.empty))
                    subscription.handler(subscription.cancellable, .dictionary([
                        "type": "current",
                        "notifications": ["first": [:], "second": [:]],
                    ]))
                default:
                    subscription.initiated(.success(.empty))
                }
            }
            let expectation1 = await waitUntil {
                answerRequests(on: context.connection, from: &answered)
                return context.viewModel.user?.name == "Jane"
                    && context.viewModel.mainItems.contains { $0.id == "energy" }
            }
            #expect(expectation1)
        }
    }

    @Test("A sidebar started before its API exists subscribes once the API connects")
    func startBeforeTheAPIExistsSubscribesOnConnect() async throws {
        let previousCachedApis = Current.cachedApis
        defer { Current.cachedApis = previousCachedApis }
        let suiteName = "MacSidebarViewModelConnectionTests.lateStart"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let server = Server.fake { info in
            info.connection.set(address: nil, for: .internal)
            info.connection.set(address: nil, for: .external)
            info.connection.set(address: nil, for: .remoteUI)
        }
        let viewModel = MacSidebarViewModel(
            server: server,
            overlayState: WebFrontendOverlayState(),
            snapshotStore: MacSidebarSnapshotStore(userDefaults: userDefaults)
        )
        defer { viewModel.stop() }

        viewModel.start()
        #expect(Current.api(for: server) == nil)

        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        server.update { info in
            info.connection.set(address: URL(string: "https://example.com"), for: .external)
        }
        Current.setCachedApi(api, for: server.identifier)
        NotificationCenter.default.post(name: HomeAssistantAPI.didConnectNotification, object: nil)

        let subscribed = await waitUntil { !connection.pendingRequests.isEmpty }
        #expect(subscribed)

        // A second connect must not double the subscriptions.
        let requestCount = connection.pendingRequests.count
        NotificationCenter.default.post(name: HomeAssistantAPI.didConnectNotification, object: nil)
        try await Task.sleep(for: .milliseconds(50))
        #expect(connection.pendingRequests.count == requestCount)
    }

    @Test func editsAreSavedBackToTheServer() async throws {
        try await withViewModel { context in
            context.viewModel.start()
            var answered = 0
            let expectation2 = await waitUntil {
                answerRequests(on: context.connection, from: &answered)
                return context.viewModel.mainItems.count > 1
            }
            #expect(expectation2)
            let sentBefore = context.connection.pendingRequests.count

            let ids = context.viewModel.mainItems.map(\.id)
            context.viewModel.reorderItems(to: Array(ids.reversed()))
            if let hideable = context.viewModel.mainItems.first(where: { context.viewModel.canHide($0) }) {
                context.viewModel.hide(itemId: hideable.id)
                context.viewModel.show(itemId: hideable.id)
            }
            context.viewModel.show(itemId: "not-hidden")
            context.viewModel.hide(itemId: "missing")

            let saves = context.connection.pendingRequests.dropFirst(sentBefore)
                .filter { $0.request.type.command == "frontend/set_user_data" }
            #expect(!saves.isEmpty)
            for save in saves {
                save.completion(.failure(.internal(debugDescription: "rejected")))
            }
        }
    }
}
