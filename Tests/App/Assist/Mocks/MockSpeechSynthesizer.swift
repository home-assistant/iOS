@testable import HomeAssistant

final class MockSpeechSynthesizer: SpeechSynthesizerProtocol {
    var onFinished: (() -> Void)?

    var speakCalled = false
    var stopCalled = false
    var lastSpokenText: String?

    func speak(_ text: String) {
        speakCalled = true
        lastSpokenText = text
    }

    func stop() {
        stopCalled = true
    }

    func simulateFinished() {
        onFinished?()
    }
}
