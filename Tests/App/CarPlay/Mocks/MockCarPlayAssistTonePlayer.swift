@testable import HomeAssistant

final class MockCarPlayAssistTonePlayer: CarPlayAssistTonePlayerProtocol {
    var playedTones: [CarPlayAssistTonePlayer.Tone] = []
    var stopCalled = false
    /// When true (default), play completions run immediately, mirroring a tone that finishes
    /// instantly. Set false to hold the completion in `pendingCompletion`.
    var autoCompletePlayback = true
    var pendingCompletion: (() -> Void)?

    func play(_ tone: CarPlayAssistTonePlayer.Tone, completion: (() -> Void)?) {
        playedTones.append(tone)
        if autoCompletePlayback {
            completion?()
        } else {
            pendingCompletion = completion
        }
    }

    func stop() {
        stopCalled = true
        pendingCompletion = nil
    }
}
