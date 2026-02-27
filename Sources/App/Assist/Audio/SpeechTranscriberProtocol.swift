import Foundation

protocol SpeechTranscriberProtocol: AnyObject {
    var delegate: SpeechTranscriberDelegate? { get set }
    func startTranscribing(locale: Locale)
    func stopTranscribing()
}

protocol SpeechTranscriberDelegate: AnyObject {
    func speechTranscriberDidTranscribe(_ text: String)
    func speechTranscriberDidFinish(finalText: String)
    func speechTranscriberDidFail(error: Error)
}

/// No-op transcriber used when on-device STT is not available (pre-iOS 17).
final class NoOpSpeechTranscriber: SpeechTranscriberProtocol {
    weak var delegate: SpeechTranscriberDelegate?
    func startTranscribing(locale: Locale) {}
    func stopTranscribing() {}
}
