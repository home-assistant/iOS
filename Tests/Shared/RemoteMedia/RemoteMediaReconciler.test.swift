import Foundation
@testable import Shared
import Testing

struct RemoteMediaReconcilerTests {
    /// No real delays: the ladder's timing is a product decision, not something to spend test
    /// seconds re-measuring.
    private let delays: [Duration] = Array(repeating: .zero, count: 4)

    private func snapshot(
        state: String = "playing",
        contentId: String? = "track-a",
        position: TimeInterval? = 0,
        volume: Double? = 0.5
    ) -> RemoteMediaSnapshot {
        .init(
            selection: .init(serverId: "home", entityId: "media_player.echo"),
            deviceName: "Echo", deviceClass: nil, state: state,
            title: "Title", artist: "Artist", album: "Album", contentId: contentId,
            duration: 200, position: position, positionUpdatedAtUnix: nil, artwork: nil,
            volume: volume, isMuted: false, features: [.play, .pause, .next, .seek, .volumeSet]
        )
    }

    private final class Server: @unchecked Sendable {
        var readbacks: [RemoteMediaStateReadback]
        var error: Error?
        private(set) var calls = 0
        init(_ readbacks: [RemoteMediaStateReadback]) { self.readbacks = readbacks }

        func fetch() async throws -> RemoteMediaStateReadback {
            calls += 1
            if let error { throw error }
            return readbacks.isEmpty ? .unreadable : readbacks.removeFirst()
        }
    }

    private func run(
        _ server: Server,
        until condition: RemoteMediaSettleCondition
    ) async -> [RemoteMediaStateReadback] {
        let collected = Collected()
        await RemoteMediaReconciler(delays: delays, fetch: server.fetch)
            .reconcile(until: condition) { await collected.append($0) }
        return await collected.values
    }

    private actor Collected {
        var values: [RemoteMediaStateReadback] = []
        func append(_ value: RemoteMediaStateReadback) { values.append(value) }
    }

    @Test func nextRetriesUntilTheTrackChanges() async {
        let server = Server([
            .entity(.init(snapshot: snapshot(contentId: "track-a"), artworkSource: nil)),
            .entity(.init(snapshot: snapshot(contentId: "track-a"), artworkSource: nil)),
            .entity(.init(snapshot: snapshot(contentId: "track-b"), artworkSource: nil)),
        ])
        let updates = await run(server, until: .trackChanged(from: snapshot(contentId: "track-a").trackId))
        #expect(server.calls == 3)
        #expect(updates.count == 3)
    }

    /// An Echo blanks its metadata mid-change; that empty report is not the new track.
    @Test func blankMetadataDoesNotCountAsATrackChange() async {
        let blank = snapshot(contentId: nil)
        let cleared = RemoteMediaSnapshot(
            selection: blank.selection, deviceName: "Echo", deviceClass: nil, state: "idle",
            title: nil, artist: nil, album: nil, contentId: nil, duration: nil, position: nil,
            positionUpdatedAtUnix: nil, artwork: nil, volume: nil, isMuted: nil, features: []
        )
        let server = Server([
            .entity(.init(snapshot: cleared, artworkSource: nil)),
            .entity(.init(snapshot: snapshot(contentId: "track-b"), artworkSource: nil)),
        ])
        _ = await run(server, until: .trackChanged(from: snapshot(contentId: "track-a").trackId))
        #expect(server.calls == 2)
    }

    @Test func pauseSettlesOnPausedAndToleratesTransientIdle() async {
        let viaIdle = Server([
            .entity(.init(snapshot: snapshot(state: "playing"), artworkSource: nil)),
            .entity(.init(snapshot: snapshot(state: "idle"), artworkSource: nil)),
        ])
        _ = await run(viaIdle, until: .notPlaying)
        // `idle` is already "not playing", so it settles there rather than burning the whole ladder.
        #expect(viaIdle.calls == 2)

        let direct = Server([.entity(.init(snapshot: snapshot(state: "paused"), artworkSource: nil))])
        _ = await run(direct, until: .notPlaying)
        #expect(direct.calls == 1)
    }

    @Test func playSettlesOnPlayingOrBuffering() async {
        let server = Server([.entity(.init(snapshot: snapshot(state: "buffering"), artworkSource: nil))])
        _ = await run(server, until: .playing)
        #expect(server.calls == 1)
    }

    @Test func seekAndVolumeUseTolerance() async {
        let seek = Server([.entity(.init(snapshot: snapshot(position: 62), artworkSource: nil))])
        _ = await run(seek, until: .position(60))
        #expect(seek.calls == 1)

        let volume = Server([.entity(.init(snapshot: snapshot(volume: 0.42), artworkSource: nil))])
        _ = await run(volume, until: .volume(0.4))
        #expect(volume.calls == 1)

        let far = Server([.entity(.init(snapshot: snapshot(volume: 0.9), artworkSource: nil))])
        _ = await run(far, until: .volume(0.4))
        #expect(far.calls == delays.count)
    }

    @Test func retriesAreBounded() async {
        let server = Server([])
        server.readbacks = Array(
            repeating: .entity(.init(snapshot: snapshot(contentId: "track-a"), artworkSource: nil)),
            count: 20
        )
        _ = await run(server, until: .trackChanged(from: snapshot(contentId: "track-a").trackId))
        #expect(server.calls == delays.count)
    }

    @Test func networkFailureFailsGracefullyWithoutUpdating() async {
        let server = Server([])
        server.error = URLError(.notConnectedToInternet)
        let updates = await run(server, until: .playing)
        #expect(updates.isEmpty)
        #expect(server.calls == delays.count)
    }

    @Test func aMissingEntityStopsImmediately() async {
        let server = Server([.missing])
        let updates = await run(server, until: .playing)
        #expect(server.calls == 1)
        #expect(updates == [.missing])
    }

    @Test func stopSettlesButIsNotAnEndOfSession() async {
        let server = Server([.entity(.init(snapshot: snapshot(state: "idle"), artworkSource: nil))])
        let updates = await run(server, until: .stopped)
        #expect(server.calls == 1)
        // The readback still carries media, so the card stays.
        if case let .entity(state) = updates[0] {
            #expect(state.snapshot.hasMeaningfulMedia)
        } else {
            Issue.record("expected an entity readback")
        }
    }

    @Test func settleConditionPerCommand() {
        let playing = snapshot(state: "playing")
        #expect(
            RemoteMediaSettleCondition.forCommand(.next, value: nil, previous: playing)
                == .trackChanged(from: playing.trackId)
        )
        #expect(
            RemoteMediaSettleCondition.forCommand(.previous, value: nil, previous: playing)
                == .trackChanged(from: playing.trackId)
        )
        #expect(RemoteMediaSettleCondition.forCommand(.play, value: nil, previous: playing) == .playing)
        #expect(RemoteMediaSettleCondition.forCommand(.pause, value: nil, previous: playing) == .notPlaying)
        #expect(RemoteMediaSettleCondition.forCommand(.stop, value: nil, previous: playing) == .stopped)
        #expect(RemoteMediaSettleCondition.forCommand(.seek, value: 30, previous: playing) == .position(30))
        #expect(RemoteMediaSettleCondition.forCommand(.volume, value: 0.3, previous: playing) == .volume(0.3))
        // Toggle depends on where it started.
        #expect(
            RemoteMediaSettleCondition.forCommand(.togglePlayPause, value: nil, previous: playing)
                == .notPlaying
        )
        #expect(RemoteMediaSettleCondition.forCommand(
            .togglePlayPause, value: nil, previous: snapshot(state: "paused")
        ) == .playing)
    }
}
