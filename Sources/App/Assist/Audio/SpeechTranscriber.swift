import Shared
import SpeechTranscriber

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

/// Adapter that wraps the SPM `SpeechTranscriber` package and conforms to `SpeechTranscriberProtocol`.
/// The SPM package manages its own audio engine internally, so no external audio buffer forwarding is needed.
@MainActor
final class SpeechTranscriberAdapter: SpeechTranscriberProtocol {
    nonisolated weak var delegate: SpeechTranscriberDelegate?

    private var transcriber: SpeechTranscriber?

    nonisolated func startTranscribing(locale: Locale) {
        Task { @MainActor in
            await performStartTranscribing(locale: locale)
        }
    }

    nonisolated func stopTranscribing() {
        Task { @MainActor in
            performStopTranscribing()
        }
    }

    private func performStartTranscribing(locale: Locale) async {
        let newTranscriber = SpeechTranscriber(locale: locale)
        transcriber = newTranscriber

        newTranscriber.onTranscriptUpdate = { [weak self] text, isFinal in
            guard let self else { return }
            delegate?.speechTranscriberDidTranscribe(text)
            if isFinal {
                delegate?.speechTranscriberDidFinish(finalText: text)
                transcriber = nil
            }
        }

        newTranscriber.onError = { [weak self] error in
            guard let self else { return }
            delegate?.speechTranscriberDidFail(error: error)
            transcriber = nil
        }

        do {
            try await newTranscriber.startListening()
        } catch {
            Current.Log.error("Failed to start on-device speech transcription: \(error.localizedDescription)")
            delegate?.speechTranscriberDidFail(error: error)
            transcriber = nil
        }
    }

    private func performStopTranscribing() {
        guard let transcriber else { return }
        let finalText = transcriber.transcript
        transcriber.stopListening()
        self.transcriber = nil

        if !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delegate?.speechTranscriberDidFinish(finalText: finalText)
        }
    }
}
