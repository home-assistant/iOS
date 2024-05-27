import AVFoundation
import Foundation
import Shared

protocol AudioPlayerProtocol {
    func play(url: URL)
    func pause()
}

final class AudioPlayer: NSObject, AudioPlayerProtocol {
    private let player = AVPlayer()

    func play(url: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
        } catch {
            Current.Log.error("Failed to setup audio session for audio player: \(error.localizedDescription)")
        }

        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }

    func pause() {
        player.pause()
    }
}
