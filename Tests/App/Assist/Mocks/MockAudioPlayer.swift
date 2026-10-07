import Foundation
@testable import HomeAssistant
import Shared

final class MockAudioPlayer: AudioPlayerProtocol {
    var delegate: (any HomeAssistant.AudioPlayerDelegate)?

    var playUrl: URL?
    var playServer: Server?
    var playCalled = false
    var pauseCalled = false

    func play(url: URL, server: Server?) {
        playUrl = url
        playServer = server
        playCalled = true
    }

    func pause() {
        pauseCalled = true
    }
}
