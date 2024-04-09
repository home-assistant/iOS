import AVFoundation
import Foundation

protocol AudioPlayerProtocol {
    func play(url: URL)
    func pause()
}

final class AudioPlayer: NSObject, AudioPlayerProtocol {
    private let player = AVPlayer()

    func play(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }

    func pause() {
        player.pause()
    }
}
