import AVFoundation
import Shared
import Speech

protocol SpeechTranscriberProtocol: AnyObject {
    var delegate: SpeechTranscriberDelegate? { get set }
    func startTranscribing(locale: Locale)
    func stopTranscribing()
    func sendAudioBuffer(_ buffer: AVAudioPCMBuffer)
}

protocol SpeechTranscriberDelegate: AnyObject {
    func speechTranscriberDidTranscribe(_ text: String)
    func speechTranscriberDidFinish(finalText: String)
    func speechTranscriberDidFail(error: Error)
}

enum SpeechTranscriberError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineFailure

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Speech recognition is not authorized. Please enable it in Settings."
        case .recognizerUnavailable:
            "Speech recognizer is not available for the selected language."
        case .audioEngineFailure:
            "Failed to start audio engine."
        }
    }
}

final class SpeechTranscriber: SpeechTranscriberProtocol {
    weak var delegate: SpeechTranscriberDelegate?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastTranscription: String = ""

    func startTranscribing(locale: Locale) {
        // Stop any existing transcription
        stopTranscribing()

        let recognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer = recognizer

        guard let recognizer, recognizer.isAvailable else {
            delegate?.speechTranscriberDidFail(error: SpeechTranscriberError.recognizerUnavailable)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        lastTranscription = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                lastTranscription = text
                delegate?.speechTranscriberDidTranscribe(text)

                if result.isFinal {
                    delegate?.speechTranscriberDidFinish(finalText: text)
                    cleanUp()
                }
            }

            if let error, self.recognitionTask != nil {
                Current.Log.error("Speech recognition error: \(error.localizedDescription)")
                delegate?.speechTranscriberDidFail(error: error)
                cleanUp()
            }
        }
    }

    func stopTranscribing() {
        recognitionRequest?.endAudio()
        recognitionTask?.finish()

        if !lastTranscription.isEmpty {
            delegate?.speechTranscriberDidFinish(finalText: lastTranscription)
        }

        cleanUp()
    }

    func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    private func cleanUp() {
        recognitionRequest = nil
        recognitionTask = nil
        speechRecognizer = nil
    }
}
