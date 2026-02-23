import AVFoundation
@testable import HomeAssistant

final class MockSpeechTranscriber: SpeechTranscriberProtocol {
    weak var delegate: SpeechTranscriberDelegate?

    var startTranscribingCalled = false
    var stopTranscribingCalled = false
    var sendAudioBufferCalled = false
    var startLocale: Locale?

    func startTranscribing(locale: Locale) {
        startTranscribingCalled = true
        startLocale = locale
    }

    func stopTranscribing() {
        stopTranscribingCalled = true
    }

    func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        sendAudioBufferCalled = true
    }
}
