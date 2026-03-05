@testable import HomeAssistant

final class MockSpeechTranscriber: SpeechTranscriberProtocol {
    weak var delegate: SpeechTranscriberDelegate?

    var startTranscribingCalled = false
    var stopTranscribingCalled = false
    var startLocale: Locale?

    func startTranscribing(locale: Locale) {
        startTranscribingCalled = true
        startLocale = locale
    }

    func stopTranscribing() {
        stopTranscribingCalled = true
    }
}
