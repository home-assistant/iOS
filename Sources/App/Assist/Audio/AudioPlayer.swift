import AVFoundation
import Foundation
import Shared

protocol AudioPlayerProtocol {
    var delegate: AudioPlayerDelegate? { get set }
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

    func play(url: URL) {
        let audioSession = AVAudioSession.sharedInstance()

        // Each step is attempted independently: if deactivation fails (e.g. while the
        // recorder's capture session is still tearing down), the category switch below must
        // still run — otherwise the session can stay in the output-less .record category
        // and playback is silent.
        do {
            try audioSession.setActive(false)
        } catch {
            Current.Log.error("Failed to deactivate audio session before playback: \(error.localizedDescription)")
        }
        do {
            try audioSession.setCategory(.playback)
        } catch {
            Current.Log.error("Failed to set playback category for audio player: \(error.localizedDescription)")
        }
        do {
            try audioSession.setActive(true)
        } catch {
            Current.Log.error("Failed to activate audio session for audio player: \(error.localizedDescription)")
        }

        Current.Log.verbose("Audio player current volume: \(audioSession.outputVolume)")

        if audioSession.outputVolume == 0 {
            delegate?.volumeIsZero()
            return
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
