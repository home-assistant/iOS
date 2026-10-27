import Foundation
@testable import HomeAssistant
import MediaPlayer
import Testing

@MainActor
@Suite(.serialized)
struct SendspinNowPlayingTests {
    @Test func publishesTheTrackAndTheGroupControls() {
        var commands: [String] = []
        let nowPlaying = SendspinNowPlaying { commands.append($0.command) }
        nowPlaying.update(
            metadata: SendspinMetadataState(
                timestamp: 0,
                title: "Song",
                artist: "Artist",
                albumArtist: nil,
                album: "Album",
                artworkURL: nil,
                year: nil,
                track: nil,
                progress: SendspinTrackProgress(trackProgress: 1000, trackDuration: 180_000, playbackSpeed: 1000)
            ),
            positionMs: 1500
        )
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        #expect(info?[MPMediaItemPropertyTitle] as? String == "Song")
        #expect(info?[MPMediaItemPropertyPlaybackDuration] as? Double == 180)
        #expect(info?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double == 1.5)

        nowPlaying.update(controller: SendspinControllerState(
            supportedCommands: ["play", "pause", "next"],
            volume: 50,
            muted: false,
            repeat: "off",
            shuffle: false,
            seekMaxMs: nil
        ))
        let center = MPRemoteCommandCenter.shared()
        #expect(center.nextTrackCommand.isEnabled)
        #expect(!center.previousTrackCommand.isEnabled)

        nowPlaying.update(controller: nil)
        #expect(!center.nextTrackCommand.isEnabled)
        nowPlaying.update(metadata: nil, positionMs: nil)
        #expect(MPNowPlayingInfoCenter.default().nowPlayingInfo == nil)
        #expect(commands.isEmpty)
    }
}
