import Foundation
@testable import Shared
import Testing

struct RemoteMediaSnapshotReducerTests {
    private func snapshot(
        state: String = "playing",
        title: String? = "Track",
        artist: String? = "Artist",
        album: String? = "Album",
        contentId: String? = "content-1",
        duration: TimeInterval? = 200,
        position: TimeInterval? = 10,
        volume: Double? = 0.5,
        artwork: RemoteMediaArtworkDescriptor? = nil
    ) -> RemoteMediaSnapshot {
        .init(
            selection: .init(serverId: "home", entityId: "media_player.echo"),
            deviceName: "Echo",
            deviceClass: nil,
            state: state,
            title: title,
            artist: artist,
            album: album,
            contentId: contentId,
            duration: duration,
            position: position,
            positionUpdatedAtUnix: 0,
            artwork: artwork,
            volume: volume,
            isMuted: false,
            features: [.play, .pause, .next]
        )
    }

    private var blank: RemoteMediaSnapshot {
        snapshot(state: "idle", title: nil, artist: nil, album: nil, contentId: nil, duration: nil, position: nil)
    }

    private func reduce(
        _ previous: RemoteMediaSnapshot?,
        _ incoming: RemoteMediaSnapshot
    ) -> RemoteMediaSnapshot? {
        RemoteMediaSnapshotReducer.reduce(previous: previous, incoming: incoming)
    }

    @Test func playingToPausedKeepsTheMedia() throws {
        let previous = snapshot()
        let result = try #require(reduce(previous, snapshot(state: "paused")))
        #expect(result.title == "Track")
        #expect(result.playback == .paused)
    }

    /// An Echo answering Pause passes through `idle` before settling on `paused`.
    @Test func playingToIdleKeepsTheMedia() throws {
        let result = try #require(reduce(snapshot(), snapshot(state: "idle")))
        #expect(result.title == "Track")
        #expect(result.hasMeaningfulMedia)
        #expect(result.playback == .stopped)
    }

    @Test func idleWithClearedMetadataKeepsTheMedia() throws {
        let result = try #require(reduce(snapshot(), blank))
        #expect(result.title == "Track")
        #expect(result.artist == "Artist")
        #expect(result.contentId == "content-1")
        #expect(result.hasMeaningfulMedia)
    }

    @Test func unavailableKeepsTheMediaAndTheLastKnownPlaybackState() throws {
        let previous = snapshot()
        let unavailable = snapshot(
            state: "unavailable", title: nil, artist: nil, album: nil,
            contentId: nil, duration: nil, position: nil
        )
        let result = try #require(reduce(previous, unavailable))
        #expect(result.title == "Track")
        // Not reporting is not the same as having stopped.
        #expect(result.playback == .playing)
    }

    @Test func stoppingPlaybackDoesNotEndTheSession() throws {
        // `media_stop` lands as a state change, never as the absence of a session: the user is
        // still following this player.
        let result = try #require(reduce(snapshot(), snapshot(
            state: "idle",
            title: nil,
            artist: nil,
            album: nil,
            contentId: nil,
            duration: nil,
            position: nil
        )))
        #expect(result.hasMeaningfulMedia)
    }

    @Test func aNewTrackReplacesTheMediaEntirely() throws {
        let previous = snapshot(artwork: .init(cacheKey: String(repeating: "a", count: 64)))
        let next = snapshot(title: "Second", contentId: "content-2")
        let result = try #require(reduce(previous, next))
        #expect(result.title == "Second")
        #expect(result.contentId == "content-2")
        // Correct metadata with no art beats correct metadata with the previous track's art.
        #expect(result.artwork == nil)
    }

    @Test func theSameTrackKeepsItsArtworkWhileDynamicValuesMove() throws {
        let art = RemoteMediaArtworkDescriptor(cacheKey: String(repeating: "b", count: 64))
        let previous = snapshot(artwork: art)
        let result = try #require(reduce(previous, snapshot(state: "paused", position: 90, volume: 0.9)))
        #expect(result.artwork == art)
        #expect(result.position == 90)
        #expect(result.volume == 0.9)
        #expect(result.playback == .paused)
    }

    @Test func theSameTrackAdoptsArtworkThatArrivesLater() throws {
        let art = RemoteMediaArtworkDescriptor(cacheKey: String(repeating: "c", count: 64))
        let result = try #require(reduce(snapshot(), snapshot(artwork: art)))
        #expect(result.artwork == art)
    }

    @Test func nothingMeaningfulYetShowsNothing() {
        #expect(reduce(nil, blank) == nil)
        // And a previous snapshot that never had media cannot rescue it either.
        #expect(reduce(blank, blank) == nil)
    }

    @Test func theFirstMeaningfulReportStartsTheCard() throws {
        let result = try #require(reduce(blank, snapshot()))
        #expect(result.title == "Track")
    }
}
