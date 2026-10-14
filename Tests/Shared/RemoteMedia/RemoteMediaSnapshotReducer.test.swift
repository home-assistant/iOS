import Foundation
import Shared
import Testing

struct RemoteMediaSnapshotReducerTests {
    // MARK: - The track: a transition matrix

    /// What was shown before a report arrived.
    enum Previous: String, Sendable {
        case nothing
        /// `track-1`, "Song" by "Artist" on "Album", 200s long, 10s in.
        case identifiedByContentId
        /// "Song", with no content id.
        case titleOnly
        /// "Song" by "Artist", with no content id.
        case titleAndArtist
    }

    /// What the track ends up as, compared field by field.
    struct Expected: Sendable {
        var title: String?
        var artist: String?
        var album: String?
        var contentId: String?
        var duration: TimeInterval?
        var position: TimeInterval?
        var artwork: Artwork
    }

    /// Which picture the track ends up with. Every `previous` report offers one.
    enum Artwork: Sendable {
        /// The previous report's: the incoming one did not mention a picture.
        case previous
        /// The incoming report's.
        case incoming
        case none
    }

    struct Transition: Sendable, CustomTestStringConvertible {
        let name: String
        let previous: Previous
        let state: String
        /// The incoming report's attributes.
        let incoming: String
        /// `nil` when there should be no track at all.
        let expected: Expected?

        var testDescription: String { name }
    }

    private static let song = Expected(
        title: "Song", artist: "Artist", album: "Album", contentId: "track-1", duration: 200, position: 10,
        artwork: .previous
    )
    private static let picture = #""entity_picture": "/api/media_player_proxy/x?token=t&cache=a""#
    private static let newPicture = #""entity_picture": "/api/media_player_proxy/x?token=t&cache=b""#

    static let transitions: [Transition] = [
        // Nothing to show yet.
        .init(
            name: "nothing, then a blank report",
            previous: .nothing,
            state: "idle",
            incoming: "{}",
            expected: nil
        ),
        .init(
            name: "nothing, then a content id alone",
            previous: .nothing,
            state: "playing",
            incoming: #"{"media_content_id": "track-1"}"#,
            expected: .init(contentId: "track-1", artwork: .none)
        ),

        // Reports that identify nothing keep the previous track whole.
        .init(
            name: "a blank report",
            previous: .identifiedByContentId,
            state: "idle",
            incoming: "{}",
            expected: song
        ),
        .init(
            name: "a duration alone",
            previous: .identifiedByContentId,
            state: "playing",
            incoming: #"{"media_duration": 200, "media_position": 30}"#,
            expected: song
        ),

        // The same content id: metadata that is missing is incomplete, not different.
        .init(
            name: "same content id, metadata gone",
            previous: .identifiedByContentId,
            state: "playing",
            incoming: #"{"media_content_id": "track-1", \#(newPicture)}"#,
            expected: with(song) { $0.artwork = .incoming }
        ),
        .init(
            name: "same content id and title, more to say",
            previous: .identifiedByContentId,
            state: "paused",
            incoming: #"""
            {"media_content_id": "track-1", "media_title": "Song", "media_position": 50,
             "media_position_updated_at": "2026-09-06T12:00:40+00:00"}
            """#,
            expected: with(song) { $0.position = 50 }
        ),
        .init(
            name: "same content id, a different picture",
            previous: .identifiedByContentId,
            state: "playing",
            incoming: #"{"media_content_id": "track-1", \#(newPicture)}"#,
            expected: with(song) { $0.artwork = .incoming }
        ),

        // The same content id with conflicting metadata: a stream that keeps one id across songs.
        .init(
            name: "same content id, new title",
            previous: .identifiedByContentId,
            state: "playing",
            incoming: #"{"media_content_id": "track-1", "media_title": "Next", \#(newPicture)}"#,
            expected: .init(title: "Next", contentId: "track-1", artwork: .incoming)
        ),

        // A different content id is a different track, whatever else agrees.
        .init(
            name: "new content id, same title",
            previous: .identifiedByContentId,
            state: "playing",
            incoming: #"{"media_content_id": "track-2", "media_title": "Song", \#(newPicture)}"#,
            expected: .init(title: "Song", contentId: "track-2", artwork: .incoming)
        ),

        // Without a content id on one side, agreeing metadata is the evidence, in either direction.
        .init(
            name: "content id dropped, same title",
            previous: .identifiedByContentId,
            state: "playing",
            incoming: #"{"media_title": "Song"}"#,
            expected: song
        ),
        .init(
            name: "content id appears, same title",
            previous: .titleOnly,
            state: "playing",
            incoming: #"{"media_content_id": "track-1", "media_title": "Song"}"#,
            expected: .init(title: "Song", contentId: "track-1", artwork: .previous)
        ),
        .init(
            name: "no content id, metadata arriving",
            previous: .titleOnly,
            state: "playing",
            incoming: #"{"media_title": "Song", "media_artist": "Artist", \#(newPicture)}"#,
            expected: .init(title: "Song", artist: "Artist", artwork: .incoming)
        ),
        .init(
            name: "no content id, metadata leaving",
            previous: .titleAndArtist,
            state: "playing",
            incoming: #"{"media_title": "Song"}"#,
            expected: .init(title: "Song", artist: "Artist", artwork: .previous)
        ),
        .init(
            name: "no content id, new title",
            previous: .titleAndArtist,
            state: "playing",
            incoming: #"{"media_title": "Two", "media_artist": "Artist", \#(newPicture)}"#,
            expected: .init(title: "Two", artist: "Artist", artwork: .incoming)
        ),
        // Nothing in common is not evidence of the same track.
        .init(
            name: "content id dropped, unrelated metadata",
            previous: .identifiedByContentId,
            state: "playing",
            incoming: #"{"media_album_name": "Other Album"}"#,
            expected: .init(album: "Other Album", artwork: .none)
        ),
        .init(
            name: "no content id, unrelated metadata",
            previous: .titleOnly,
            state: "playing",
            incoming: #"{"media_artist": "Artist", \#(newPicture)}"#,
            expected: .init(artist: "Artist", artwork: .incoming)
        ),
    ]

    private static func with(_ expected: Expected, _ change: (inout Expected) -> Void) -> Expected {
        var expected = expected
        change(&expected)
        return expected
    }

    @Test(arguments: transitions)
    func trackTransitions(_ transition: Transition) throws {
        let previous: RemoteMediaEntityState? = switch transition.previous {
        case .nothing:
            nil
        case .identifiedByContentId:
            try entity("playing", #"""
            {"media_content_id": "track-1", "media_title": "Song", "media_artist": "Artist",
             "media_album_name": "Album", "media_duration": 200, "media_position": 10,
             "media_position_updated_at": "2026-09-06T12:00:00+00:00", \#(Self.picture)}
            """#)
        case .titleOnly:
            try entity("playing", #"{"media_title": "Song", \#(Self.picture)}"#)
        case .titleAndArtist:
            try entity("playing", #"{"media_title": "Song", "media_artist": "Artist", \#(Self.picture)}"#)
        }
        let incoming = try entity(transition.state, transition.incoming)

        let result = reduce(previous, incoming)
        guard let expected = transition.expected else {
            #expect(result.snapshot.track == nil)
            #expect(result.artworkSource == nil)
            return
        }
        let actual = try #require(result.snapshot.track)
        let contentKey = try expected.contentId.map { contentId in
            try #require(entity("playing", #"{"media_content_id": "\#(contentId)"}"#).snapshot.track?.contentKey)
        }
        #expect(actual.title == expected.title)
        #expect(actual.artist == expected.artist)
        #expect(actual.album == expected.album)
        #expect(actual.contentKey == contentKey)
        #expect(actual.duration == expected.duration)
        #expect(actual.position == expected.position)
        // A timestamp only ever travels with the position it dates.
        #expect((actual.positionUpdatedAtUnix != nil) == (expected.position != nil))

        // The cover and the source it can be fetched from are one fact, so they are checked together.
        switch expected.artwork {
        case .previous:
            #expect(actual.artwork == .deferred)
            let source = try #require(previous?.artworkSource)
            #expect(result.artworkSource == source)
        case .incoming:
            #expect(actual.artwork == .deferred)
            // The same picture, though bound to the track the reducer kept rather than to the one the
            // incoming report would have founded on its own.
            let source = try #require(incoming.artworkSource)
            #expect(result.artworkSource?.reference == source.reference)
        case .none:
            #expect(actual.artwork == .absent)
            #expect(result.artworkSource == nil)
        }
    }

    // MARK: - Sparse reports with nothing in common

    /// A content key alone and a title alone share no evidence that they are the same track, so neither
    /// is merged into the other, in either direction, and nothing of the old track (or its cover) leaks.
    @Test func aContentKeyAloneThenATitleAloneIsADifferentTrack() throws {
        let previous = try entity("playing", #"{"media_content_id": "track-1", \#(Self.picture)}"#)
        let result = try reduce(previous, entity("playing", #"{"media_title": "Song"}"#))
        let track = try #require(result.snapshot.track)
        #expect(track.title == "Song")
        #expect(track.contentKey == nil)
        #expect(track.artwork == .absent)
        #expect(result.artworkSource == nil)
        #expect(result.artworkSource != previous.artworkSource)
    }

    @Test func aTitleAloneThenAContentKeyAloneIsADifferentTrack() throws {
        let previous = try entity("playing", #"{"media_title": "Song", \#(Self.picture)}"#)
        let result = try reduce(previous, entity("playing", #"{"media_content_id": "track-1"}"#))
        let track = try #require(result.snapshot.track)
        #expect(track.title == nil)
        #expect(track.contentKey != nil)
        #expect(track.artwork == .absent)
        #expect(result.artworkSource == nil)
    }

    // MARK: - The player

    /// Keeping the old song on screen is no reason to keep the old name, volume or controls.
    @Test func aReportWithoutATrackStillUpdatesThePlayer() throws {
        let previous = try entity("playing", Self.player)
        let incoming = try entity("idle", #"""
        {"friendly_name": "Kitchen Echo", "device_class": "speaker", "volume_level": 0.9, "supported_features": 4}
        """#)
        let result = reduce(previous, incoming)
        #expect(result.snapshot.track == previous.snapshot.track)
        #expect(result.snapshot.player.name == "Kitchen Echo")
        #expect(result.snapshot.player.deviceClass == "speaker")
        #expect(result.snapshot.player.volume == 0.9)
        #expect(result.snapshot.player.features == .volumeSet)
        #expect(result.snapshot.player.playback == .stopped)
    }

    @Test func theSameTrackStillUpdatesThePlayer() throws {
        let previous = try entity("playing", Self.player)
        let incoming = try entity("paused", #"""
        {"friendly_name": "Echo", "volume_level": 0.2, "supported_features": 16387, "media_title": "Song"}
        """#)
        let result = reduce(previous, incoming)
        #expect(result.snapshot.player.playback == .paused)
        #expect(result.snapshot.player.volume == 0.2)
        #expect(result.snapshot.player.features == [.play, .pause, .seek])
    }

    /// Not saying is not the same as having stopped, so the last known playback state stands —
    /// while everything else about the player still follows the report.
    @Test(arguments: ["unavailable", "unknown"])
    func anIndeterminateStateKeepsThePreviousPlaybackState(_ state: String) throws {
        let previous = try entity("paused", Self.player)
        let incoming = try entity(state, #"{"friendly_name": "Echo", "supported_features": 1}"#)
        let result = reduce(previous, incoming)
        #expect(result.snapshot.player.playback == .paused)
        #expect(result.snapshot.player.volume == nil)
        #expect(result.snapshot.player.features == .pause)
    }

    @Test func anIndeterminateStateWithNothingBeforeItStaysIndeterminate() throws {
        let result = try reduce(nil, entity("unavailable", "{}"))
        #expect(result.snapshot.player.playback == .indeterminate)
        #expect(result.snapshot.track == nil)
    }

    // MARK: - Positions

    /// A position and the moment it was measured are one fact; a report without one keeps both.
    @Test func theSameTrackWithoutAPositionKeepsThePreviousPositionAndItsTimestamp() throws {
        let previous = try entity("playing", Self.player)
        let incoming = try entity("playing", #"{"media_title": "Song", "media_position": true}"#)
        let track = try #require(reduce(previous, incoming).snapshot.track)
        #expect(track.position == 10)
        #expect(track.positionUpdatedAtUnix == 1_788_696_000)
    }

    /// An invalid position is no position, whether omitted or sent: the retained pair stands, and the
    /// timestamp that came with the invalid one is not paired with it.
    @Test func anInvalidPositionKeepsThePreviousPositionAndItsTimestamp() throws {
        let previous = try entity("playing", Self.player)
        let incoming = try entity("playing", #"""
        {"media_title": "Song", "media_position": -5, "media_position_updated_at": "2026-09-06T12:05:00+00:00"}
        """#)
        let track = try #require(reduce(previous, incoming).snapshot.track)
        #expect(track.position == 10)
        #expect(track.positionUpdatedAtUnix == 1_788_696_000)
    }

    @Test func theSameTrackWithANewPositionTakesItsTimestampToo() throws {
        let previous = try entity("playing", Self.player)
        let incoming = try entity("playing", #"""
        {"media_title": "Song", "media_position": 90, "media_position_updated_at": "2026-09-06T12:01:20+00:00"}
        """#)
        let track = try #require(reduce(previous, incoming).snapshot.track)
        #expect(track.position == 90)
        #expect(track.positionUpdatedAtUnix == 1_788_696_080)
        #expect(track.duration == 200)
    }

    @Test func aNewPositionWithoutATimestampDropsTheOldTimestamp() throws {
        let previous = try entity("playing", Self.player)
        let incoming = try entity("playing", #"{"media_title": "Song", "media_position": 90}"#)
        let track = try #require(reduce(previous, incoming).snapshot.track)
        #expect(track.position == 90)
        #expect(track.positionUpdatedAtUnix == nil)
    }

    /// A retained measurement that no longer fits the new duration is dropped with its timestamp, not
    /// rewritten into a position nobody measured.
    @Test func aShorterDurationDropsAnIncompatibleKeptPositionAndTimestamp() throws {
        let previous = try entity("playing", #"""
        {"media_title": "Song", "media_duration": 200, "media_position": 190,
         "media_position_updated_at": "2026-09-06T12:00:00+00:00"}
        """#)
        let incoming = try entity("playing", #"{"media_title": "Song", "media_duration": 100}"#)
        let track = try #require(reduce(previous, incoming).snapshot.track)
        #expect(track.duration == 100)
        #expect(track.position == nil)
        #expect(track.positionUpdatedAtUnix == nil)
    }

    @Test func aKeptPositionThatStillFitsIsUnchanged() throws {
        let previous = try entity("playing", #"""
        {"media_title": "Song", "media_duration": 200, "media_position": 90,
         "media_position_updated_at": "2026-09-06T12:00:00+00:00"}
        """#)
        let incoming = try entity("playing", #"{"media_title": "Song", "media_duration": 100}"#)
        let track = try #require(reduce(previous, incoming).snapshot.track)
        #expect(track.duration == 100)
        #expect(track.position == 90)
        #expect(track.positionUpdatedAtUnix == 1_788_696_000)
    }

    // MARK: - Helpers

    private static let player = #"""
    {
        "friendly_name": "Echo", "volume_level": 0.5, "supported_features": 16435,
        "media_title": "Song", "media_duration": 200, "media_position": 10,
        "media_position_updated_at": "2026-09-06T12:00:00+00:00"
    }
    """#

    private func reduce(
        _ previous: RemoteMediaEntityState?,
        _ incoming: RemoteMediaEntityState
    ) -> RemoteMediaEntityState {
        RemoteMediaSnapshotReducer.reduce(previous: previous, incoming: incoming)
    }

    private func entity(_ state: String = "playing", _ json: String) throws -> RemoteMediaEntityState {
        try RemoteMediaFixtures.mapped(state, json)
    }
}
