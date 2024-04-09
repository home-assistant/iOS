import Foundation
@testable import HomeAssistant

final class MockAudioPlayer: AudioPlayerProtocol {
    var playUrl: URL?
    var playCalled = false
    var pauseCalled = false

    func play(url: URL) {
        playUrl = url
        playCalled = true
    }

    func pause() {
        pauseCalled = true
    }
}
