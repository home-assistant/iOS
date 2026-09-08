import Foundation
@testable import Shared
import Testing

/// Finishing dismissals that never reached Home Assistant.
///
/// Stopping cannot wait for the network, so what is owed is written down and a later launch sends
/// it. This is the launch.
@MainActor
@Suite(.serialized)
struct RemoteMediaDismissalReconcilerTests {
    private static let serverId = "home"
    private static let selection = RemoteMediaSelection(
        serverId: serverId, entityId: "media_player.speaker"
    )

    private final class Recorder: @unchecked Sendable {
        var sent: [RemoteMediaSessionDismissal] = []
        var contexts: [RemoteMediaTransportContext] = []
        var failure: Error?

        var sender: RemoteMediaDismissalSender {
            .init { [self] end in
                sent.append(end.dismissal)
                contexts.append(end.context)
                if let failure { throw failure }
            }
        }
    }

    private func pending(
        serverId: String = RemoteMediaDismissalReconcilerTests.serverId,
        entityId: String = "media_player.speaker",
        generation: String = "A",
        sequence: Int = 10
    ) -> RemoteMediaPendingDismissal {
        .init(
            serverId: serverId,
            entityId: entityId,
            sessionId: RemoteMediaSelection(serverId: serverId, entityId: entityId).id,
            generation: generation,
            generationSequence: sequence
        )
    }

    /// Runs `body` with one server configured under `serverId`, and puts the world back.
    private func withWorld(
        servers configured: [String],
        records: [RemoteMediaPendingDismissal],
        _ body: (Recorder) async throws -> Void
    ) async rethrows {
        let store = Current.settingsStore
        let previousRecords = store.remoteMediaPendingDismissals
        let previousServers = Current.servers
        let previousSender = RemoteMediaDismissalReconciler.sender
        defer {
            store.remoteMediaPendingDismissals = previousRecords
            Current.servers = previousServers
            RemoteMediaDismissalReconciler.sender = previousSender
        }

        let servers = FakeServerManager(initial: 0)
        for identifier in configured {
            servers.add(identifier: .init(rawValue: identifier), serverInfo: .fake())
        }
        Current.servers = servers
        store.remoteMediaPendingDismissals = records

        let recorder = Recorder()
        RemoteMediaDismissalReconciler.sender = recorder.sender
        try await body(recorder)
    }

    @Test func nothingHappensWhenNothingIsOwed() async {
        await withWorld(servers: [Self.serverId], records: []) { recorder in
            await RemoteMediaDismissalReconciler.reconcile()
            #expect(recorder.sent.isEmpty)
        }
    }

    /// The transport is rebuilt from the server as it is configured now — the routes and the
    /// secret are exactly what must never be persisted.
    @Test func anOwedDismissalIsSentAndForgotten() async throws {
        let record = pending()
        try await withWorld(servers: [Self.serverId], records: [record]) { recorder in
            await RemoteMediaDismissalReconciler.reconcile()
            #expect(recorder.sent == [record.dismissal])
            let context = try #require(recorder.contexts.first)
            #expect(context.selection.serverId == Self.serverId)
            #expect(!context.webhookURLs.isEmpty)
            #expect(Current.settingsStore.remoteMediaPendingDismissals.isEmpty)
        }
    }

    @Test func aFailedRetryStaysOwed() async {
        let record = pending()
        await withWorld(servers: [Self.serverId], records: [record]) { recorder in
            recorder.failure = URLError(.notConnectedToInternet)
            await RemoteMediaDismissalReconciler.reconcile()
            #expect(recorder.sent.count == 1)
            #expect(Current.settingsStore.remoteMediaPendingDismissals == [record])

            // A later launch tries again, and succeeding clears it.
            recorder.failure = nil
            await RemoteMediaDismissalReconciler.reconcile()
            #expect(recorder.sent.count == 2)
            #expect(Current.settingsStore.remoteMediaPendingDismissals.isEmpty)
        }
    }

    /// There is nothing left to tell a server the user has removed from the app, and Home
    /// Assistant drops the registration with its config entry.
    @Test func aRecordForARemovedServerIsDropped() async {
        let record = pending(serverId: "gone")
        await withWorld(servers: [Self.serverId], records: [record]) { recorder in
            await RemoteMediaDismissalReconciler.reconcile()
            #expect(recorder.sent.isEmpty)
            #expect(Current.settingsStore.remoteMediaPendingDismissals.isEmpty)
        }
    }

    /// A dismissal owed for an earlier relationship must not disturb the one that is current. The
    /// sequence is what makes the server ignore it, so what matters here is that the retry names
    /// the old relationship and nothing else.
    @Test func aRetryNamesTheOldRelationshipAndNotTheCurrentOne() async throws {
        let store = Current.settingsStore
        let previousSelection = store.remoteMediaSelection
        let previousLifetime = store.remoteMediaFollowLifetime
        let previousSequence = store.remoteMediaFollowSequence
        defer {
            store.remoteMediaSelection = previousSelection
            store.remoteMediaFollowLifetime = previousLifetime
            store.remoteMediaFollowSequence = previousSequence
        }

        let old = pending(generation: "A", sequence: 10)
        try await withWorld(servers: [Self.serverId], records: [old]) { recorder in
            // The user has since followed again; this is the relationship that is current.
            store.remoteMediaSelection = Self.selection
            store.remoteMediaFollowSequence = 10
            let current = try #require(store.startRemoteMediaFollowLifetime(following: Self.selection))
            #expect(current.sequence == 11)

            await RemoteMediaDismissalReconciler.reconcile()
            let sent = try #require(recorder.sent.first)
            #expect(sent.generation == "A")
            #expect(sent.generationSequence == 10)
            // Strictly older than what is current, which is what the server orders by.
            #expect(sent.generationSequence < current.sequence)
            // And nothing local moved.
            #expect(store.remoteMediaFollowLifetime == current)
            #expect(store.remoteMediaSelection == Self.selection)
        }
    }

    @Test func everyOwedDismissalIsAttempted() async {
        let records = [
            pending(entityId: "media_player.one", generation: "A", sequence: 1),
            pending(entityId: "media_player.two", generation: "B", sequence: 2),
        ]
        await withWorld(servers: [Self.serverId], records: records) { recorder in
            await RemoteMediaDismissalReconciler.reconcile()
            #expect(recorder.sent.count == 2)
            #expect(Current.settingsStore.remoteMediaPendingDismissals.isEmpty)
        }
    }
}
