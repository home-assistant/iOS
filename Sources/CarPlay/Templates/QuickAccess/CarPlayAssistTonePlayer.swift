import AVFoundation
import Foundation
import Shared

protocol CarPlayAssistTonePlayerProtocol: AnyObject {
    func play(_ tone: CarPlayAssistTonePlayer.Tone, completion: (() -> Void)?)
    func stop()
}

extension CarPlayAssistTonePlayerProtocol {
    func play(_ tone: CarPlayAssistTonePlayer.Tone) {
        play(tone, completion: nil)
    }
}

/// Plays the CarPlay Assist feedback sounds through the shared audio session instead of the
/// system sound server, so they behave like media playback: routed with the rest of the
/// Assist audio and not silenced by the iPhone ring/silent switch.
///
/// The sounds are from the Home Assistant Voice Preview Edition set (CC BY 4.0, Clayton
/// Charles Tapp), bundled from `Sources/App/Resources/Sounds/Assist`.
final class CarPlayAssistTonePlayer: NSObject, CarPlayAssistTonePlayerProtocol {
    enum Tone: CaseIterable {
        /// Assist started listening; the Voice PE wake word chime.
        case listening
        /// Assist is processing the request, which also marks the end of listening; the Voice PE
        /// unmute sound.
        case processing
        /// Assist failed; the Voice PE mute sound.
        case error

        var resourceName: String {
            switch self {
            case .listening: "wake_word_triggered"
            case .processing: "mute_switch_off"
            case .error: "mute_switch_on"
            }
        }

        static let resourceExtension = "m4a"
    }

    /// Serial queue protecting `player` and `completion`; calls arrive from CarPlay template
    /// callbacks, HAKit and URLSession threads, and AVAudioPlayer delegate callbacks.
    private let queue = DispatchQueue(label: "io.home-assistant.carplay-assist-tone-player")
    private let bundle: Bundle
    private var player: AVAudioPlayer?
    private var completion: (() -> Void)?
    private var cachedToneURLs: [Tone: URL] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        super.init()
    }

    /// Plays `tone` through the currently configured audio session. `completion` runs once
    /// playback finishes or fails to start; it does not run if the tone is interrupted by
    /// `stop()` or another `play(_:completion:)` call. `completion` must not call back into
    /// this player.
    func play(_ tone: Tone, completion: (() -> Void)? = nil) {
        queue.sync {
            self.completion = nil
            player?.stop()
            player = nil

            guard let url = toneURL(for: tone) else {
                Current.Log.error("CarPlay Assist tone player is missing the \(tone) sound")
                completion?()
                return
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                self.player = player
                self.completion = completion
                if !player.play() {
                    Current.Log.error("CarPlay Assist tone player failed to start playback")
                    finishPlayback()
                }
            } catch {
                Current.Log.error("CarPlay Assist tone player failed to create player: \(error.localizedDescription)")
                completion?()
            }
        }
    }

    /// Synchronously stops any playing tone without firing its pending completion, so the
    /// audio session can be deactivated right afterwards.
    func stop() {
        queue.sync {
            completion = nil
            player?.stop()
            player = nil
        }
    }

    private func finishPlayback() {
        player = nil
        let pendingCompletion = completion
        completion = nil
        pendingCompletion?()
    }

    private func toneURL(for tone: Tone) -> URL? {
        if let cached = cachedToneURLs[tone] {
            return cached
        }
        guard let url = bundle.url(forResource: tone.resourceName, withExtension: Tone.resourceExtension) else {
            return nil
        }
        cachedToneURLs[tone] = url
        return url
    }
}

// MARK: - AVAudioPlayerDelegate

extension CarPlayAssistTonePlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        queue.async { [weak self] in
            guard let self, self.player === player else { return }
            finishPlayback()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Current.Log.error("CarPlay Assist tone player decode error: \(error?.localizedDescription ?? "unknown error")")
        queue.async { [weak self] in
            guard let self, self.player === player else { return }
            finishPlayback()
        }
    }
}
