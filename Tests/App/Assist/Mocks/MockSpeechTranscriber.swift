@testable import HomeAssistant

@MainActor
final class MockSpeechTranscriber: SpeechTranscriberProtocol {
    var onTranscriptUpdate: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?
    var onListeningStateChange: ((Bool) -> Void)?

    var startListeningCalled = false
    var stopListeningCalled = false
    var startListeningError: Error?

    func startListening() async throws {
        startListeningCalled = true
        if let error = startListeningError {
            throw error
        }
    }

    func stopListening() {
        stopListeningCalled = true
    }

    func simulateTranscriptUpdate(_ text: String, isFinal: Bool) {
        onTranscriptUpdate?(text, isFinal)
    }

    func simulateError(_ error: Error) {
        onError?(error)
    }

    func simulateListeningStateChange(_ isListening: Bool) {
        onListeningStateChange?(isListening)
    }
}
