import AVFoundation
import Foundation
import Speech

/// `WyomingSpeechRecognizing` backed by Apple's Speech framework.
///
/// Pinned to the on-device recogniser: sending a Home Assistant user's audio to Apple's servers is
/// the opposite of what running the pipeline locally is for, so a locale without on-device support
/// is refused rather than quietly handled in the cloud.
@MainActor
final class SystemSpeechRecognizer: WyomingSpeechRecognizing {
    private let recognizer: SFSpeechRecognizer
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw WyomingProtocolError.speechRecognitionUnavailable(locale.identifier)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw WyomingProtocolError.speechRecognitionUnavailable(locale.identifier)
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw WyomingProtocolError.speechRecognitionNotAuthorized
        }

        self.recognizer = recognizer
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        // Partial results are the fallback the session answers with when no final result arrives,
        // so they are worth the extra callbacks even though only the last one is ever sent.
        request.shouldReportPartialResults = true
    }

    func start(
        onTranscript: @escaping (String, Bool) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        task = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result {
                    onTranscript(result.bestTranscription.formattedString, result.isFinal)
                }
                if let error {
                    onFailure(error)
                }
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }

    func endAudio() {
        request.endAudio()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
