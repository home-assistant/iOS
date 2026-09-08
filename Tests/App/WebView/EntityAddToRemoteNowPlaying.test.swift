@testable import HomeAssistant
@testable import Shared
import Testing

/// The suite itself carries no `@available`: swift-testing refuses to apply `@Test` to a function
/// marked unavailable, so each test checks at runtime, like the other version-gated suites here.
///
/// Serialized because every case writes the followed player to the shared settings store.
@Suite(.serialized)
@MainActor
struct EntityAddToRemoteNowPlayingTests {
    private static let serverId = ServerFixture.standard.identifier.rawValue
    private static let entityId = "media_player.speaker"

    /// Held by the suite: the handler only keeps a weak reference, and a released controller means
    /// no server to match the followed player against.
    private let webViewController = MockWebViewController()

    /// Runs `body` with `selection` persisted as the followed player, restoring what was there.
    private func withFollowed(_ selection: RemoteMediaSelection?, _ body: () async throws -> Void) async rethrows {
        let previous = Current.settingsStore.remoteMediaSelection
        defer { Current.settingsStore.remoteMediaSelection = previous }
        Current.settingsStore.remoteMediaSelection = selection
        try await body()
    }

    private func makeHandler() -> EntityAddToHandler {
        EntityAddToHandler(webViewController: webViewController)
    }

    @available(iOS 27.0, *)
    private func remoteAction(for entityId: String) async throws -> RemoteNowPlayingAction? {
        let handler = makeHandler()
        let actions = try await handler.actionsForEntity(entityId: entityId).asyncValue()
        return actions.compactMap { $0 as? RemoteNowPlayingAction }.first
    }

    /// Unwraps in its own step: SwiftFormat rewrites `try #require(await …)` into a macro name that
    /// does not exist, so the `await` has to stay out of the macro call.
    @available(iOS 27.0, *)
    private func requiredRemoteAction(for entityId: String) async throws -> RemoteNowPlayingAction {
        let action = try await remoteAction(for: entityId)
        return try #require(action)
    }

    @Test func offeredForAMediaPlayer() async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(nil) {
            let action = try await requiredRemoteAction(for: Self.entityId)
            #expect(!action.isFollowing)
            #expect(action.text() == L10n.WebView.AddTo.Option.RemoteNowPlaying.title)
            #expect(action.details() == L10n.WebView.AddTo.Option.RemoteNowPlaying.details)
            #expect(action.mdiIcon == "mdi:speaker-play")
        }
    }

    @Test(arguments: ["light.kitchen", "sensor.temperature", "script.good_night"])
    func notOfferedForOtherDomains(entityId: String) async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(nil) {
            let action = try await remoteAction(for: entityId)
            #expect(action == nil)
        }
    }

    @Test func offersToStopForTheFollowedPlayer() async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(.init(serverId: Self.serverId, entityId: Self.entityId)) {
            let action = try await requiredRemoteAction(for: Self.entityId)
            #expect(action.isFollowing)
            #expect(action.text() == L10n.WebView.AddTo.Option.RemoteNowPlaying.stopTitle)
            #expect(action.details() == L10n.WebView.AddTo.Option.RemoteNowPlaying.stopDetails)
        }
    }

    @Test func offersToFollowAnotherPlayerWhileOneIsFollowed() async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(.init(serverId: Self.serverId, entityId: "media_player.kitchen")) {
            let action = try await requiredRemoteAction(for: Self.entityId)
            #expect(!action.isFollowing)
        }
    }

    /// Two servers can hold the same entity id, so the followed player is only "this one" when the
    /// server matches as well.
    @Test func aDifferentServerWithTheSameEntityIdStillOffersToFollow() async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(.init(serverId: "another-server", entityId: Self.entityId)) {
            let action = try await requiredRemoteAction(for: Self.entityId)
            #expect(!action.isFollowing)
        }
    }

    /// Every execution case runs with both payloads: the row is built when the frontend asks for
    /// actions and can be tapped much later, so what it said then must not decide what happens now.
    @available(iOS 27.0, *)
    private func execute(rowSaidFollowing: Bool) async throws {
        let handler = makeHandler()
        try await handler.execute(
            action: RemoteNowPlayingAction(isFollowing: rowSaidFollowing),
            entityId: Self.entityId
        ).asyncValue()
    }

    @Test(arguments: [false, true])
    func followsWhenNothingIsFollowed(rowSaidFollowing: Bool) async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(nil) {
            try await execute(rowSaidFollowing: rowSaidFollowing)
            #expect(Current.settingsStore.remoteMediaSelection == .init(
                serverId: Self.serverId,
                entityId: Self.entityId
            ))
        }
    }

    @Test(arguments: [false, true])
    func stopsWhenThisPlayerIsAlreadyFollowed(rowSaidFollowing: Bool) async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(.init(serverId: Self.serverId, entityId: Self.entityId)) {
            try await execute(rowSaidFollowing: rowSaidFollowing)
            #expect(Current.settingsStore.remoteMediaSelection == nil)
        }
    }

    @Test(arguments: [false, true])
    func switchesFromAnotherPlayer(rowSaidFollowing: Bool) async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(.init(serverId: Self.serverId, entityId: "media_player.kitchen")) {
            try await execute(rowSaidFollowing: rowSaidFollowing)
            #expect(Current.settingsStore.remoteMediaSelection == .init(
                serverId: Self.serverId,
                entityId: Self.entityId
            ))
        }
    }

    /// The same entity id on another server is a different player, so tapping this one follows it
    /// rather than reading as "already followed" and stopping.
    @Test func executionMatchesOnServerAsWellAsEntity() async throws {
        guard #available(iOS 27.0, *) else { return }
        try await withFollowed(.init(serverId: "another-server", entityId: Self.entityId)) {
            try await execute(rowSaidFollowing: true)
            #expect(Current.settingsStore.remoteMediaSelection == .init(
                serverId: Self.serverId,
                entityId: Self.entityId
            ))
        }
    }

    @Test func roundTripsThroughTheFrontendPayload() async throws {
        guard #available(iOS 27.0, *) else { return }
        for isFollowing in [true, false] {
            let external = try ExternalEntityAddToAction.from(action: RemoteNowPlayingAction(isFollowing: isFollowing))
            #expect(external.mdiIcon == "mdi:speaker-play")
            let decoded = try #require(
                ExternalEntityAddToAction.toAction(from: external.appPayload) as? RemoteNowPlayingAction
            )
            #expect(decoded.isFollowing == isFollowing)
            #expect(decoded.text() == external.name)
            #expect(decoded.details() == external.details)
        }
    }

    /// The new case must not disturb the payloads the frontend already round-trips.
    @Test func existingActionsStillRoundTrip() throws {
        let actions: [any EntityAddToAction] = [
            CarPlayQuickAccessAction(),
            WatchItemAction(),
            CustomWidgetAction(),
            MacToolbarItemAction(),
            DeeplinkAction(),
        ]
        for action in actions {
            let external = try ExternalEntityAddToAction.from(action: action)
            let decoded = try ExternalEntityAddToAction.toAction(from: external.appPayload)
            #expect(decoded.actionType == action.actionType)
            #expect(decoded.text() == action.text())
        }
    }
}
