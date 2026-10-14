import Foundation
import Shared
import Testing

struct RemoteMediaFeaturesTests {
    /// Home Assistant Core's `MediaPlayerEntityFeature` values, written out literally so a typo fails here.
    static let understoodBits: [(Int, RemoteMediaFeatures)] = [
        (1, .pause), (2, .seek), (4, .volumeSet), (16, .previousTrack), (32, .nextTrack), (4096, .stop),
        (16384, .play), (16385, [.play, .pause]),
        (20535, [.pause, .seek, .volumeSet, .previousTrack, .nextTrack, .stop, .play]),
    ]

    @Test(arguments: understoodBits)
    func eachUnderstoodBitSurvivesMapping(_ supportedFeatures: Int, _ expected: RemoteMediaFeatures) throws {
        let player = try RemoteMediaFixtures.report("playing", #"{"supported_features": \#(supportedFeatures)}"#).player
        #expect(player.features == expected)
    }

    /// Unused bits are dropped before anything is built, so they never reach a snapshot either.
    @Test func mappingKeepsOnlyUnderstoodBits() throws {
        // PLAY | SEEK | PAUSE, plus VOLUME_MUTE, TURN_ON and BROWSE_MEDIA.
        let player = try RemoteMediaFixtures.report("playing", #"{"supported_features": 147595}"#).player
        #expect(player.features == [.play, .seek, .pause])
        #expect(player.features.rawValue == 16387)
    }

    /// `VOLUME_MUTE`, `TURN_ON`, `TURN_OFF`, `SELECT_SOURCE`, `SHUFFLE_SET`, `SEARCH_MEDIA`.
    @Test(arguments: [8, 128, 256, 2048, 32768, 4_194_304])
    func bitsThisFeatureDoesNotUseAreDropped(_ supportedFeatures: Int) throws {
        let player = try RemoteMediaFixtures.report("playing", #"{"supported_features": \#(supportedFeatures)}"#).player
        #expect(player.features.isEmpty)
    }

    @Test(arguments: [
        #"{"supported_features": -1}"#,
        #"{"supported_features": -16387}"#,
        #"{"supported_features": 16387.0}"#,
        #"{"supported_features": "16387"}"#,
        #"{"supported_features": null}"#,
        #"{"supported_features": [1]}"#,
        "{}",
    ])
    func anythingButANonNegativeIntegerIsNoFeatures(_ json: String) throws {
        let player = try RemoteMediaFixtures.report("playing", json).player
        #expect(player.features.isEmpty)
    }
}
