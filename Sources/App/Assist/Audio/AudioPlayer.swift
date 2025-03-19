import AVFoundation
import Foundation
import Shared

protocol AudioPlayerProtocol {
    var delegate: AudioPlayerDelegate? { get set }
    var volume: Float? { get }
    func play(url: URL)
    func pause()
}

protocol AudioPlayerDelegate: AnyObject {
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer)
    func volumeIsZero()
}

final class AudioPlayer: NSObject, AudioPlayerProtocol {
    weak var delegate: AudioPlayerDelegate?
    private let player = AVPlayer()

    var volume: Float? {
        AVAudioSession.sharedInstance().outputVolume
    }

    func play(url: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)

            Current.Log.verbose("Audio player current volume: \(audioSession.outputVolume)")

            if audioSession.outputVolume == 0 {
                delegate?.volumeIsZero()
                return
            }
        } catch {
            Current.Log.error("Failed to setup audio session for audio player: \(error.localizedDescription)")
        }

        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    func pause() {
        player.pause()
    }

    @objc private func audioDidFinishPlaying(_ notification: Notification) {
        delegate?.audioPlayerDidFinishPlaying(self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
