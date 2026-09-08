import AVFoundation
import Foundation
import Shared
import Speech

/// Transcribes one Wyoming audio stream: PCM arrives in `append`, and `finish` reports what the
/// recogniser made of it once the client's `audio-stop` closes the stream.
///
/// Recognition is pinned to the on-device recogniser. Sending a Home Assistant user's audio to
/// Apple's servers is the opposite of what running the pipeline locally is for, so a locale without
/// on-device support is refused rather than quietly handled in the cloud.
@MainActor
final class WyomingSpeechRecognitionSession {
    /// How long to wait for a final result after the audio ends before answering with the best
    /// transcript so far. The recogniser can cancel after `endAudio()` without ever delivering an
    /// `isFinal` result, which would otherwise hang the client until it times out.
    private static let finalResultGracePeriod: TimeInterval = 2

    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var converter: WyomingPCMConverter

    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var receivedAudio = false
    private var result: Result<String, Error>?
    private var continuation: CheckedContinuation<String, Error>?
    private var graceTask: Task<Void, Never>?

    init(locale: Locale, format: WyomingAudioFormat) throws {
        self.converter = try WyomingPCMConverter(format: format)

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw WyomingProtocolError.speechRecognitionUnavailable(locale.identifier)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw WyomingProtocolError.speechRecognitionUnavailable(locale.identifier)
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw WyomingProtocolError.speechRecognitionNotAuthorized
        }

        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        // Partial results are the fallback `finish` answers with when no final result arrives, so
        // they are worth the extra callbacks even though only the last one is ever sent.
        request.shouldReportPartialResults = true

        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handle(result: result, error: error)
            }
        }
    }

    func append(_ audio: Data) {
        guard let buffer = converter.convert(audio) else { return }
        receivedAudio = true
        request.append(buffer)
    }

    /// Closes the audio stream and waits for the transcript.
    func finish() async throws -> String {
        guard receivedAudio else {
            cancel()
            throw WyomingProtocolError.noAudioReceived
        }

        request.endAudio()
        startGracePeriod()

        return try await withCheckedThrowingContinuation { continuation in
            if let result {
                continuation.resume(with: result)
            } else {
                self.continuation = continuation
            }
        }
    }

    func cancel() {
        graceTask?.cancel()
        graceTask = nil
        task?.cancel()
        task = nil
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            latestTranscript = result.bestTranscription.formattedString
            if result.isFinal {
                complete(.success(latestTranscript))
                return
            }
        }

        guard let error else { return }
        // The recogniser cancels the task as a matter of course once `endAudio()` has been called,
        // so an error after the audio ended is only a failure when nothing was recognised at all.
        if latestTranscript.isEmpty {
            complete(.failure(error))
        } else {
            complete(.success(latestTranscript))
        }
    }

    private func startGracePeriod() {
        graceTask?.cancel()
        graceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.finalResultGracePeriod * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.complete(.success(self.latestTranscript))
        }
    }

    private func complete(_ result: Result<String, Error>) {
        guard self.result == nil else { return }
        self.result = result
        graceTask?.cancel()
        graceTask = nil
        continuation?.resume(with: result)
        continuation = nil
    }
}
