import AVFoundation
import Foundation
import Shared

/// Transcribes one Wyoming audio stream: PCM arrives in `append`, and `finish` reports what the
/// recogniser made of it once the client's `audio-stop` closes the stream.
@MainActor
final class WyomingSpeechRecognitionSession {
    /// How long to wait for a final result after the audio ends before answering with the best
    /// transcript so far. The recogniser can cancel after `endAudio()` without ever delivering a
    /// final result, which would otherwise hang the client until it times out.
    static let defaultGracePeriod: TimeInterval = 2

    private let recognizer: any WyomingSpeechRecognizing
    private let gracePeriod: TimeInterval
    private var converter: WyomingPCMConverter

    private var latestTranscript = ""
    private var receivedAudio = false
    private var result: Result<String, Error>?
    private var continuation: CheckedContinuation<String, Error>?
    private var graceTask: Task<Void, Never>?

    /// The audio format is validated before the recogniser is built, so a client sending something
    /// other than 16-bit PCM is told exactly that rather than whatever the recogniser complains
    /// about first.
    init(
        format: WyomingAudioFormat,
        gracePeriod: TimeInterval = WyomingSpeechRecognitionSession.defaultGracePeriod,
        makeRecognizer: () throws -> any WyomingSpeechRecognizing
    ) throws {
        self.converter = try WyomingPCMConverter(format: format)
        self.recognizer = try makeRecognizer()
        self.gracePeriod = gracePeriod

        recognizer.start(
            onTranscript: { [weak self] transcript, isFinal in
                self?.handle(transcript: transcript, isFinal: isFinal)
            },
            onFailure: { [weak self] error in
                self?.handle(failure: error)
            }
        )
    }

    convenience init(locale: Locale, format: WyomingAudioFormat) throws {
        try self.init(format: format) { try SystemSpeechRecognizer(locale: locale) }
    }

    func append(_ audio: Data) {
        guard let buffer = converter.convert(audio) else { return }
        receivedAudio = true
        recognizer.append(buffer)
    }

    /// Closes the audio stream and waits for the transcript.
    func finish() async throws -> String {
        guard receivedAudio else {
            cancel()
            throw WyomingProtocolError.noAudioReceived
        }

        recognizer.endAudio()
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
        recognizer.cancel()
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }

    private func handle(transcript: String, isFinal: Bool) {
        latestTranscript = transcript
        if isFinal {
            complete(.success(transcript))
        }
    }

    private func handle(failure: Error) {
        // The recogniser cancels the task as a matter of course once `endAudio()` has been called,
        // so a failure after the audio ended only counts when nothing was recognised at all.
        if latestTranscript.isEmpty {
            complete(.failure(failure))
        } else {
            complete(.success(latestTranscript))
        }
    }

    private func startGracePeriod() {
        graceTask?.cancel()
        graceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.gracePeriod ?? 0) * 1_000_000_000))
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
