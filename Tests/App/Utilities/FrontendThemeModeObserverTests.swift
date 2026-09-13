import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct FrontendThemeModeObserverTests {
    @Test func theRememberedModeIsAppliedWhileTheWebsocketIsStillConnecting() throws {
        try withContext { context in
            context.remember("dark", for: context.server)

            context.observer.observe(server: context.server)

            #expect(context.styles == [.dark])
            #expect(context.connection.pendingSubscriptions.count == 1)
        }
    }

    @Test func aServerWithNoRememberedModeStartsOnTheDeviceAppearance() throws {
        try withContext { context in
            context.observer.observe(server: context.server)

            #expect(context.styles == [.unspecified])
        }
    }

    @Test func itSubscribesToTheAccountsThemePreferenceForAsLongAsItIsOpen() throws {
        try withContext { context in
            context.observer.observe(server: context.server)

            let request = try #require(context.connection.pendingSubscriptions.first).request
            #expect(request.type == .webSocket("frontend/subscribe_user_data"))
            #expect(request.data["key"] as? String == "theme")
            // Without this it is dropped ten seconds in, at the first reconnect.
            #expect(request.retryDuration == nil)
        }
    }

    @Test func theModeTheServerSendsIsAppliedAndRemembered() throws {
        try withContext { context in
            context.observer.observe(server: context.server)

            try context.send(["dark": true], on: context.connection)

            #expect(context.styles.last == .dark)
            #expect(context.remembered(for: context.server) == "dark")
        }
    }

    @Test func turningTheOverrideOffOnTheServerGivesTheAppearanceBackToTheDevice() throws {
        try withContext { context in
            context.observer.observe(server: context.server)

            try context.send(["dark": true], on: context.connection)
            try context.send(["theme": "default"], on: context.connection)

            #expect(context.styles.last == .unspecified)
            #expect(context.remembered(for: context.server) == "automatic")
        }
    }

    @Test func aResponseThatIsNotThePreferenceIsIgnored() throws {
        try withContext { context in
            context.observer.observe(server: context.server)

            try #require(context.connection.pendingSubscriptions.first).handler(HAMockCancellable {}, .empty)

            #expect(context.styles == [.unspecified])
        }
    }

    @Test func aCoreThatDoesNotKnowTheCommandLeavesTheDeviceInCharge() throws {
        try withContext { context in
            context.observer.observe(server: context.server)

            try #require(context.connection.pendingSubscriptions.first)
                .initiated(.failure(.internal(debugDescription: "unknown command")))

            #expect(context.styles == [.unspecified])
        }
    }

    @Test func reopeningTheSameServerDoesNotSubscribeTwice() throws {
        try withContext { context in
            context.observer.observe(server: context.server)
            context.observer.observe(server: context.server)

            #expect(context.connection.pendingSubscriptions.count == 1)
        }
    }

    @Test func switchingServerReadsThePreferenceFromTheNewOne() throws {
        try withContext { context in
            let second = context.addServer()
            let secondConnection = context.reachable(second)
            context.remember("light", for: second)

            context.observer.observe(server: context.server)
            context.observer.observe(server: second)

            #expect(context.styles.last == .light)
            #expect(context.connection.cancelledSubscriptions.count == 1)
            #expect(secondConnection.pendingSubscriptions.count == 1)

            // The server left behind answering late must not restyle the app around it.
            try context.send(["dark": true], on: context.connection)
            #expect(context.styles.last == .light)
        }
    }

    @Test func onboardingHandsTheAppearanceBackToTheDevice() throws {
        try withContext { context in
            context.observer.observe(server: context.server)
            try context.send(["dark": true], on: context.connection)

            context.observer.observe(server: nil)

            #expect(context.styles.last == .unspecified)
            #expect(context.connection.cancelledSubscriptions.count == 1)
        }
    }

    @Test func aServerWithNoReachableURLIsPickedUpOnTheNextSceneActivation() throws {
        try withContext(serverIsReachable: false) { context in
            context.observer.observe(server: context.server)
            #expect(context.styles == [.unspecified])
            #expect(context.connection.pendingSubscriptions.isEmpty)

            // The server becomes reachable, and a window activating is what notices.
            context.server.update { $0 = Self.serverInfo(reachable: true) }
            let connection = context.reachable(context.server)
            context.activateAScene()

            #expect(connection.pendingSubscriptions.count == 1)
            try context.send(["dark": true], on: connection)
            #expect(context.styles.last == .dark)

            // An observer that is already subscribed does not pile up subscriptions on every activation.
            context.activateAScene()
            #expect(connection.pendingSubscriptions.count == 1)
            #expect(context.styles.last == .dark)
        }
    }

    @Test func theStyleIsAppliedToTheWindowsTheAppIsShowing() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        defer { FrontendThemeModeObserver.overrideConnectedWindows(.unspecified) }

        FrontendThemeModeObserver.overrideConnectedWindows(.dark)

        #expect(windows.isEmpty == false)
        #expect(windows.allSatisfy { $0.overrideUserInterfaceStyle == .dark })
    }

    // MARK: - Helpers

    @MainActor
    private final class StyleRecorder {
        private(set) var styles: [UIUserInterfaceStyle] = []

        func record(_ style: UIUserInterfaceStyle) {
            styles.append(style)
        }
    }

    /// Owns the observer, so it lives long enough for a subscription to answer.
    @MainActor
    private final class Context {
        let observer: FrontendThemeModeObserver
        let server: Server
        let connection: HAMockConnection
        let servers: FakeServerManager

        private let recorder: StyleRecorder
        private let defaults: UserDefaults
        private let suiteName: String

        var styles: [UIUserInterfaceStyle] { recorder.styles }

        init(serverIsReachable: Bool) {
            let suiteName = "FrontendThemeModeObserverTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            let servers = FakeServerManager()
            let recorder = StyleRecorder()
            Current.servers = servers
            Current.cachedApis = [:]

            let server = servers.add(
                identifier: .init(rawValue: UUID().uuidString),
                serverInfo: FrontendThemeModeObserverTests.serverInfo(reachable: serverIsReachable)
            )

            self.suiteName = suiteName
            self.defaults = defaults
            self.servers = servers
            self.recorder = recorder
            self.server = server
            self.observer = FrontendThemeModeObserver(defaults: defaults, applyStyle: recorder.record)
            self.connection = HAMockConnection()

            if serverIsReachable {
                let api = HomeAssistantAPI(server: server)
                api.connection = connection
                Current.cachedApis[server.identifier] = api
            }
        }

        func tearDown() {
            defaults.removePersistentDomain(forName: suiteName)
        }

        func addServer() -> Server {
            servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: serverInfo(reachable: true))
        }

        /// Gives `server` an API backed by a mock connection, the way a reachable server has one.
        @discardableResult
        func reachable(_ server: Server) -> HAMockConnection {
            let connection = HAMockConnection()
            let api = HomeAssistantAPI(server: server)
            api.connection = connection
            Current.cachedApis[server.identifier] = api
            return connection
        }

        /// Answers the open subscription with the value it carries for the `theme` key.
        func send(_ value: [String: Any], on connection: HAMockConnection) throws {
            try #require(connection.pendingSubscriptions.last)
                .handler(HAMockCancellable {}, .dictionary(["value": value]))
        }

        func activateAScene() {
            NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
        }

        func remember(_ mode: String, for server: Server) {
            defaults.set(mode, forKey: key(for: server))
        }

        func remembered(for server: Server) -> String? {
            defaults.string(forKey: key(for: server))
        }

        private func key(for server: Server) -> String {
            "frontendThemeMode-\(server.identifier.rawValue)"
        }
    }

    private func withContext(
        serverIsReachable: Bool = true,
        _ body: (Context) throws -> Void
    ) rethrows {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        let context = Context(serverIsReachable: serverIsReachable)
        defer {
            context.tearDown()
            Current.servers = previousServers
            Current.cachedApis = previousApis
        }
        try body(context)
    }

    /// `ServerInfo.fake()` is always reachable; an unreachable one has no URL left to try.
    private static func serverInfo(reachable: Bool) -> ServerInfo {
        var info = ServerInfo.fake()
        guard !reachable else { return info }
        info.connection = .init(
            externalURL: nil,
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "FakeWebhookID",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )
        return info
    }
}
