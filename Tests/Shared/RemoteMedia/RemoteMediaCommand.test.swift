import Foundation
@testable import Shared
import Testing

struct RemoteMediaCommandTests {
    @Test func capabilitiesAreIndependent() {
        let pairs: [(RemoteMediaFeatures, RemoteMediaCommand)] = [
            (.play, .play), (.pause, .pause), (.stop, .stop), (.previous, .previous),
            (.next, .next), (.seek, .seek), (.volumeSet, .volume),
        ]
        for (feature, command) in pairs {
            #expect(feature.commands == [command])
        }
        #expect(RemoteMediaFeatures([.play, .pause]).commands == [.play, .pause, .togglePlayPause])
        #expect(RemoteMediaFeatures.volumeMute.commands.isEmpty)
        #expect(RemoteMediaFeatures(rawValue: 128).commands.isEmpty)
    }

    @Test func serviceNamesMatchHomeAssistant() {
        #expect(RemoteMediaCommand.allCases.map(\.service) == [
            "media_play", "media_pause", "media_play_pause", "media_stop",
            "media_previous_track", "media_next_track", "media_seek", "volume_set",
        ])
    }
}
