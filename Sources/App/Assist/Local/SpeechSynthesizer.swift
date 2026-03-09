import AVFoundation
import Foundation
import Shared

/// Abstraction over the on-device speech synthesizer so the view model can hold a
/// strongly-typed reference without coupling to a concrete type.
protocol SpeechSynthesizerProtocol: AnyObject {
    var onFinished: (() -> Void)? { get set }
    func speak(_ text: String)
    func stop()
}

/// A text-to-speech synthesizer using Apple's AVSpeechSynthesizer framework.
/// Speaks text locally on the device without sending audio data to a server.
final class SpeechSynthesizer: NSObject, SpeechSynthesizerProtocol, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    /// Called when the synthesizer finishes speaking an utterance.
    var onFinished: (() -> Void)?

    /// Initialize using the system default voice.
    override init() {
        self.voice = nil
        super.init()
        synthesizer.delegate = self
    }

    /// Initialize with a specific voice identifier from `AVSpeechSynthesisVoice.speechVoices()`.
    init(voiceIdentifier: String) {
        self.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            Current.Log.error("Failed to set audio session category for speech synthesis: \(error)")
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinished?()
    }
}
