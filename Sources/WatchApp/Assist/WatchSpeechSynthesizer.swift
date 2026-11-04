import AVFoundation
import Foundation
import Shared

protocol WatchSpeechSynthesizing: AnyObject {
    func speak(_ payload: AssistOnDeviceTTSPayload)
    func stop()
}

final class WatchSpeechSynthesizer: NSObject, WatchSpeechSynthesizing {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ payload: AssistOnDeviceTTSPayload) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: payload.text)
        utterance.voice = payload.voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
        configureAudioSessionForPlayback()
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func configureAudioSessionForPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false)
        } catch {
            Current.Log.error("Failed to deactivate audio session before on-device TTS: \(error.localizedDescription)")
        }
        do {
            try audioSession.setCategory(.playback, mode: .default)
        } catch {
            Current.Log.error("Failed to set playback category for on-device TTS: \(error.localizedDescription)")
        }
        do {
            try audioSession.setActive(true)
        } catch {
            Current.Log.error("Failed to activate audio session for on-device TTS: \(error.localizedDescription)")
        }
    }
}
