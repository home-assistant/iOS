import Foundation
@testable import HomeAssistant

final class MockAudioPlayer: AudioPlayerProtocol {
    var delegate: (any HomeAssistant.AudioPlayerDelegate)?

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

extension MockAudioPlayer {
    func simulateError(_ error: Error) {
        delegate?.audioPlayerDidFailWithError(error)
    }
}
