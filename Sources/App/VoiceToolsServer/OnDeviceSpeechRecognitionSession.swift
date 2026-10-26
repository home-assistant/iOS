import AVFoundation
import Foundation
import Shared

/// Transcribes one audio stream with the on-device recogniser: PCM arrives in `append`, and
/// `finish` reports what the recogniser made of it once the stream is closed.
@MainActor
final class OnDeviceSpeechRecognitionSession {
    /// How long to wait for a final result after the audio ends before answering with the best
    /// transcript so far. The recogniser can cancel after `endAudio()` without ever delivering a
    /// final result, which would otherwise hang the client until it times out.
    static let defaultGracePeriod: TimeInterval = 2
    /// How long the transcript has to stay unchanged before the speaker counts as done, the same
    /// pause the in-app transcriber waits for.
    static let defaultSilenceTimeout: TimeInterval = 1.5

    /// Called once, while the audio is still streaming in, when there is no point sending more: the
    /// words stayed the same through `silenceTimeout` of audio after there first were some, so the
    /// speaker is done, or the recogniser already settled on its answer. Lets a client streaming live
    /// audio stop recording without waiting for the user, then call `finish()`; nothing is detected
    /// while `nil`.
    var onListeningEnded: (() -> Void)?

    private let recognizer: any OnDeviceSpeechRecognizing
    private let gracePeriod: TimeInterval
    private let silenceTimeout: TimeInterval
    private var converter: WyomingPCMConverter

    private var latestTranscript = ""
    private var receivedAudio = false
    private var audioEnded = false
    private var didReportListeningEnded = false
    /// Seconds of audio appended since the words last changed.
    private var audioSinceNewSpeech: TimeInterval = 0
    private var result: Result<String, Error>?
    private var continuation: CheckedContinuation<String, Error>?
    private var graceTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?

    /// The audio format is validated before the recogniser is built, so a client sending something
    /// other than 16-bit PCM is told exactly that rather than whatever the recogniser complains
    /// about first.
    init(
        format: WyomingAudioFormat,
        gracePeriod: TimeInterval = OnDeviceSpeechRecognitionSession.defaultGracePeriod,
        silenceTimeout: TimeInterval = OnDeviceSpeechRecognitionSession.defaultSilenceTimeout,
        makeRecognizer: () throws -> any OnDeviceSpeechRecognizing
    ) throws {
        self.converter = try WyomingPCMConverter(format: format)
        self.recognizer = try makeRecognizer()
        self.gracePeriod = gracePeriod
        self.silenceTimeout = silenceTimeout

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
        audioSinceNewSpeech += Double(buffer.frameLength) / buffer.format.sampleRate
        recognizer.append(buffer)
    }

    /// Closes the audio stream and waits for the transcript.
    func finish() async throws -> String {
        endAudioStream()
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
        endAudioStream()
        graceTask?.cancel()
        graceTask = nil
        recognizer.cancel()
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }

    private func handle(transcript: String, isFinal: Bool) {
        let isNewSpeech = transcript != latestTranscript
        latestTranscript = transcript
        if isFinal {
            complete(.success(transcript))
        } else if isNewSpeech {
            audioSinceNewSpeech = 0
            startSilenceTimeout(after: silenceTimeout)
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

    /// Restarted whenever the words change. The pause is measured in audio, not in time: audio that
    /// streams in over a link can stall, and a stall is not the speaker pausing, so the wait goes on
    /// until a whole `silenceTimeout` of audio has arrived without new words.
    private func startSilenceTimeout(after delay: TimeInterval) {
        guard onListeningEnded != nil, !audioEnded, !latestTranscript.isEmpty else { return }
        silenceTask?.cancel()
        silenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            let missingSilence = silenceTimeout - audioSinceNewSpeech
            if missingSilence > 0 {
                startSilenceTimeout(after: missingSilence)
            } else {
                endListening()
            }
        }
    }

    private func endListening() {
        silenceTask?.cancel()
        silenceTask = nil
        guard !audioEnded, !didReportListeningEnded else { return }
        didReportListeningEnded = true
        onListeningEnded?()
    }

    /// No more audio is coming, so there is no listening left to end either.
    private func endAudioStream() {
        audioEnded = true
        silenceTask?.cancel()
        silenceTask = nil
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
        endListening()
    }
}
