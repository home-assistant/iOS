import AVFoundation
import Foundation
@testable import HomeAssistant
import Testing

@MainActor
struct WyomingSpeechRecognitionSessionTests {
    /// Stands in for the Speech framework, which cannot be driven without speech authorisation.
    private final class FakeRecognizer: WyomingSpeechRecognizing {
        private(set) var appendedBuffers = 0
        private(set) var didEndAudio = false
        private(set) var didCancel = false

        private var onTranscript: ((String, Bool) -> Void)?
        private var onFailure: ((Error) -> Void)?

        func start(
            onTranscript: @escaping (String, Bool) -> Void,
            onFailure: @escaping (Error) -> Void
        ) {
            self.onTranscript = onTranscript
            self.onFailure = onFailure
        }

        func append(_ buffer: AVAudioPCMBuffer) {
            appendedBuffers += 1
        }

        func endAudio() {
            didEndAudio = true
        }

        func cancel() {
            didCancel = true
        }

        func report(_ transcript: String, isFinal: Bool = false) {
            onTranscript?(transcript, isFinal)
        }

        func fail(_ error: Error) {
            onFailure?(error)
        }
    }

    private struct RecognizerFailure: Error {}

    private func makeSession(
        recognizer: FakeRecognizer,
        gracePeriod: TimeInterval = 0.05
    ) throws -> WyomingSpeechRecognitionSession {
        try WyomingSpeechRecognitionSession(
            format: .init(rate: 16000, width: 2, channels: 1),
            gracePeriod: gracePeriod
        ) { recognizer }
    }

    private func pcm(_ samples: [Int16]) -> Data {
        samples.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    @Test func answersWithTheFinalTranscript() async throws {
        let recognizer = FakeRecognizer()
        let session = try makeSession(recognizer: recognizer)
        session.append(pcm([1, 2, 3, 4]))

        let pending = Task { try await session.finish() }
        // Let `finish()` register its continuation before the recogniser answers.
        try await Task.sleep(nanoseconds: 50_000_000)
        recognizer.report("turn on the")
        recognizer.report("Turn on the kitchen light.", isFinal: true)

        let recognised = try await pending.value
        #expect(recognised == "Turn on the kitchen light.")
        #expect(recognizer.didEndAudio)
    }

    /// The recogniser routinely cancels its task once the audio ends, so a failure that arrives
    /// after words were already recognised is not a failed transcription.
    @Test func keepsWhatWasRecognisedWhenTheRecognizerFailsLate() async throws {
        let recognizer = FakeRecognizer()
        let session = try makeSession(recognizer: recognizer)
        session.append(pcm([1, 2]))

        let pending = Task { try await session.finish() }
        try await Task.sleep(nanoseconds: 50_000_000)
        recognizer.report("kitchen light")
        recognizer.fail(RecognizerFailure())

        let recognised = try await pending.value
        #expect(recognised == "kitchen light")
    }

    /// With nothing recognised there is no transcript to salvage, so the failure is the answer.
    @Test func reportsAFailureThatArrivesBeforeAnyWords() async throws {
        let recognizer = FakeRecognizer()
        let session = try makeSession(recognizer: recognizer)
        session.append(pcm([1, 2]))

        recognizer.fail(RecognizerFailure())

        await #expect(throws: RecognizerFailure.self) {
            _ = try await session.finish()
        }
    }

    /// The recogniser can go quiet after `endAudio()` without ever delivering a final result, which
    /// would otherwise hang the client until its own timeout.
    @Test func fallsBackToThePartialTranscriptWhenNoFinalArrives() async throws {
        let recognizer = FakeRecognizer()
        let session = try makeSession(recognizer: recognizer, gracePeriod: 0.05)
        session.append(pcm([1, 2]))
        recognizer.report("half a sentence")

        let transcript = try await session.finish()

        #expect(transcript == "half a sentence")
    }

    /// A stream that carried no audio has nothing to transcribe, and saying so beats an empty
    /// transcript the pipeline would read as a successful silent turn.
    @Test func refusesToFinishWhenNoAudioArrived() async {
        let recognizer = FakeRecognizer()
        let session = try? makeSession(recognizer: recognizer)

        await #expect(throws: WyomingProtocolError.noAudioReceived) {
            _ = try await session?.finish()
        }
    }

    /// Audio that does not fill a whole frame is held back, so it never reaches the recogniser as a
    /// buffer of the wrong length.
    @Test func onlyForwardsWholeFrames() throws {
        let recognizer = FakeRecognizer()
        let session = try makeSession(recognizer: recognizer)

        session.append(Data([0x01]))
        #expect(recognizer.appendedBuffers == 0)

        session.append(Data([0x02]))
        #expect(recognizer.appendedBuffers == 1)
    }

    /// The client is answered exactly once: a late final result after a failure must not resume the
    /// continuation a second time.
    @Test func answersOnlyOnce() async throws {
        let recognizer = FakeRecognizer()
        let session = try makeSession(recognizer: recognizer)
        session.append(pcm([1, 2]))

        recognizer.report("first", isFinal: true)
        recognizer.report("second", isFinal: true)
        recognizer.fail(RecognizerFailure())

        let recognised = try await session.finish()
        #expect(recognised == "first")
    }

    @Test func cancellingStopsTheRecognizer() throws {
        let recognizer = FakeRecognizer()
        let session = try makeSession(recognizer: recognizer)

        session.cancel()

        #expect(recognizer.didCancel)
    }

    /// The format is checked before the recogniser is built, so a client sending the wrong audio is
    /// told exactly that rather than whatever the recogniser objects to first.
    @Test func rejectsAnUnsupportedFormatBeforeBuildingTheRecognizer() {
        var built = false

        #expect(throws: WyomingProtocolError.self) {
            _ = try WyomingSpeechRecognitionSession(format: .init(rate: 16000, width: 4, channels: 1)) {
                built = true
                return FakeRecognizer()
            }
        }
        #expect(!built)
    }
}
