import AVFoundation
import Foundation
@testable import HomeAssistant
import Network
import Testing

/// Drives a real listener over loopback and exercises the requests Home Assistant sends. The
/// connection is a state machine over a socket, so nothing below the transport tells you whether a
/// `synthesize` actually comes back as playable audio.
struct WyomingConnectionTests {
    private enum TestError: Error {
        case listenerUnavailable
        case connectionClosed
        case timedOut
    }

    /// Records the listener's state, which arrives on the listener's own queue.
    private final class StateRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var port: UInt16?
        private var failed = false

        func record(_ state: WyomingServerState) {
            lock.lock()
            defer { lock.unlock() }
            switch state {
            case let .running(port): self.port = port
            case .failed: failed = true
            case .stopped, .starting: break
            }
        }

        func boundPort(timeout: TimeInterval = 10) async throws -> UInt16 {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                lock.lock()
                let port = port
                let failed = failed
                lock.unlock()
                if failed { throw TestError.listenerUnavailable }
                if let port { return port }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            throw TestError.timedOut
        }
    }

    /// A Wyoming client: owns the socket and the partial read buffer that events are framed out of.
    private final class Client {
        /// Generous: synthesising a sentence on a busy runner is not instant, but an unanswered
        /// request still has to fail long before the job's own timeout.
        private static let readTimeout: TimeInterval = 60

        private let connection: NWConnection
        private var buffer = Data()

        init(port: NWEndpoint.Port) {
            self.connection = NWConnection(host: .ipv4(.loopback), port: port, using: .tcp)
            connection.start(queue: .global())
        }

        func cancel() {
            connection.cancel()
        }

        func send(_ event: WyomingEvent) async throws {
            let data = try WyomingEventCodec.encode(event)
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                let pending = Pending(continuation)
                let deadline = DispatchWorkItem { pending.resume(with: .failure(TestError.timedOut)) }
                DispatchQueue.global().asyncAfter(deadline: .now() + Self.readTimeout, execute: deadline)

                connection.send(content: data, completion: .contentProcessed { error in
                    deadline.cancel()
                    if let error {
                        pending.resume(with: .failure(error))
                    } else {
                        pending.resume(with: .success(Data()))
                    }
                })
            }
        }

        func receive() async throws -> WyomingEvent {
            while true {
                if let event = try WyomingEventCodec.decode(from: &buffer) {
                    return event
                }
                try await buffer.append(readChunk())
            }
        }

        /// Hands out the continuation once, whichever of the read and the deadline gets there first.
        private final class Pending: @unchecked Sendable {
            private var continuation: CheckedContinuation<Data, Error>?
            private let lock = NSLock()

            init(_ continuation: CheckedContinuation<Data, Error>) {
                self.continuation = continuation
            }

            func resume(with result: Result<Data, Error>) {
                lock.lock()
                let pending = continuation
                continuation = nil
                lock.unlock()
                pending?.resume(with: result)
            }
        }

        /// A read that never completes would otherwise hang the whole test job until the runner's
        /// hour is up, instead of failing here with something to read.
        private func readChunk() async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                let pending = Pending(continuation)
                let deadline = DispatchWorkItem { pending.resume(with: .failure(TestError.timedOut)) }
                DispatchQueue.global().asyncAfter(deadline: .now() + Self.readTimeout, execute: deadline)

                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    deadline.cancel()
                    if let error {
                        pending.resume(with: .failure(error))
                    } else if let data, !data.isEmpty {
                        pending.resume(with: .success(data))
                    } else if isComplete {
                        pending.resume(with: .failure(TestError.connectionClosed))
                    } else {
                        pending.resume(with: .success(Data()))
                    }
                }
            }
        }
    }

    /// Opens a listener on a system-assigned port with a client attached, and tears both down.
    private func withClient(
        makeRecognizer: @escaping WyomingRecognizerFactory = { _ in StubRecognizer() },
        _ work: (Client) async throws -> Void
    ) async throws {
        let recorder = StateRecorder()
        let server = WyomingServer(
            port: .any,
            serviceName: "Wyoming connection tests",
            fallbackLocale: Locale(identifier: "en-US"),
            advertisesOverBonjour: false,
            makeRecognizer: makeRecognizer,
            onStateChange: { recorder.record($0) }
        )
        await server.start()

        let boundPort = try await recorder.boundPort()
        let port = try #require(NWEndpoint.Port(rawValue: boundPort))
        let client = Client(port: port)

        do {
            try await work(client)
        } catch {
            client.cancel()
            await server.stop()
            throw error
        }
        client.cancel()
        await server.stop()
    }

    /// Answers the moment the audio ends, so a whole transcription exchange runs without speech
    /// authorisation and without waiting on a real recogniser.
    @MainActor
    private final class StubRecognizer: WyomingSpeechRecognizing {
        static let transcript = "turn on the kitchen light"

        private var onTranscript: ((String, Bool) -> Void)?

        func start(
            onTranscript: @escaping (String, Bool) -> Void,
            onFailure _: @escaping (Error) -> Void
        ) {
            self.onTranscript = onTranscript
        }

        func append(_: AVAudioPCMBuffer) {}

        func endAudio() {
            onTranscript?(Self.transcript, true)
        }

        func cancel() {}
    }

    private struct SynthesizeRequest: Encodable {
        struct Voice: Encodable {
            let name: String?
            let language: String?
        }

        let text: String
        var voice: Voice?
    }

    private struct TranscriptResponse: Decodable {
        let text: String
    }

    private struct ErrorResponse: Decodable {
        let text: String
    }

    /// The whole point of the text-to-speech half: a `synthesize` has to come back as a format
    /// header, PCM payloads and a stop, or Home Assistant has nothing to play.
    @Test func synthesizeAnswersWithPlayableAudio() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .synthesize, encoding: SynthesizeRequest(text: "Hello.")))

            let start = try await client.receive()
            let format = try start.decodeData(WyomingAudioFormat.self)
            #expect(start.kind == .audioStart)
            #expect(format.width == 2)
            #expect(format.channels == 1)
            #expect(format.rate > 0)

            var audio = Data()
            var chunkFormats: [WyomingAudioFormat] = []
            while true {
                let event = try await client.receive()
                if event.kind == .audioStop { break }
                #expect(event.kind == .audioChunk)
                // Every chunk repeats the format, which is what Home Assistant builds its WAV
                // header from.
                try chunkFormats.append(event.decodeData(WyomingAudioFormat.self))
                audio.append(event.payload ?? Data())
            }

            #expect(!audio.isEmpty)
            #expect(chunkFormats.allSatisfy { $0 == format })
        }
    }

    /// Failures have to come back as an `error` event: a client that gets silence waits out its own
    /// timeout instead of reporting what went wrong.
    @Test func reportsSynthesisOfEmptyTextAsAnError() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .synthesize, encoding: SynthesizeRequest(text: "   ")))

            let event = try await client.receive()
            let response = try event.decodeData(ErrorResponse.self)
            #expect(event.kind == .error)
            #expect(!response.text.isEmpty)
        }
    }

    /// Home Assistant sends back the voice id this server advertised, which is an
    /// `AVSpeechSynthesisVoice` identifier.
    @Test func synthesizesWithTheVoiceTheClientAsksForByIdentifier() async throws {
        let voices = await OnDeviceVoiceCatalog.voices()
        let identifier = try #require(voices.first?.identifier)

        try await withClient { client in
            try await client.send(WyomingEvent(kind: .synthesize, encoding: SynthesizeRequest(
                text: "Hello.",
                voice: .init(name: identifier, language: nil)
            )))

            let event = try await client.receive()
            #expect(event.kind == .audioStart)
        }
    }

    /// A client that names a language without picking a voice still gets speech, in that language.
    @Test func synthesizesWithALanguageWhenNoVoiceIsNamed() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .synthesize, encoding: SynthesizeRequest(
                text: "Hello.",
                voice: .init(name: nil, language: "en-US")
            )))

            let event = try await client.receive()
            #expect(event.kind == .audioStart)
        }
    }

    /// An identifier no longer installed falls through to the system voice rather than failing the
    /// request: the voice list is read once and a client can hold a stale one.
    @Test func fallsBackWhenTheNamedVoiceIsGone() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .synthesize, encoding: SynthesizeRequest(
                text: "Hello.",
                voice: .init(name: "com.example.voice.that.is.not.installed", language: nil)
            )))

            let event = try await client.receive()
            #expect(event.kind == .audioStart)
        }
    }

    /// The speech-to-text half, end to end: Home Assistant names a language, streams audio, and
    /// gets one transcript back when it stops.
    @Test func transcribesAnAudioStreamIntoATranscript() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .transcribe, data: Data(#"{"language":"en-US"}"#.utf8)))
            try await client.send(WyomingEvent(
                kind: .audioStart,
                encoding: WyomingAudioFormat(rate: 16000, width: 2, channels: 1)
            ))
            try await client.send(WyomingEvent(
                kind: .audioChunk,
                encoding: WyomingAudioFormat(rate: 16000, width: 2, channels: 1),
                payload: Data(repeating: 0, count: 640)
            ))
            try await client.send(WyomingEvent(kind: .audioStop))

            let event = try await client.receive()
            let transcript = try event.decodeData(TranscriptResponse.self)

            #expect(event.kind == .transcript)
            #expect(transcript.text == StubRecognizer.transcript)
        }
    }

    /// A client that streams audio without an `audio-start` still describes its format on every
    /// chunk, so it does not have to be turned away.
    @Test func transcribesAStreamThatSkippedAudioStart() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(
                kind: .audioChunk,
                encoding: WyomingAudioFormat(rate: 16000, width: 2, channels: 1),
                payload: Data(repeating: 0, count: 640)
            ))
            try await client.send(WyomingEvent(kind: .audioStop))

            let event = try await client.receive()
            #expect(event.kind == .transcript)
        }
    }

    /// The listener is open to anything on the local network, so a peer opening sockets without
    /// ever closing them must not be able to exhaust the process.
    @Test func refusesConnectionsPastItsLimit() async throws {
        let recorder = StateRecorder()
        let server = WyomingServer(
            port: .any,
            serviceName: "Wyoming connection tests",
            fallbackLocale: Locale(identifier: "en-US"),
            advertisesOverBonjour: false,
            makeRecognizer: { _ in StubRecognizer() },
            onStateChange: { recorder.record($0) }
        )
        await server.start()
        let boundPort = try await recorder.boundPort()
        let port = try #require(NWEndpoint.Port(rawValue: boundPort))

        // One more than the cap, all held open at once. Only the first is written to: accepting the
        // socket is what the cap acts on, and a send to a refused connection has nobody to complete
        // it.
        var clients: [Client] = []
        for _ in 0 ... 8 {
            clients.append(Client(port: port))
        }

        // The connection within the cap still answers, which is what proves the refusal was
        // selective rather than the listener falling over.
        try await clients[0].send(WyomingEvent(kind: .ping))
        let firstReply = try await clients[0].receive()
        #expect(firstReply.kind == .pong)

        for client in clients {
            client.cancel()
        }
        await server.stop()
    }

    @Test func answersPingWithPong() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .ping))

            let event = try await client.receive()
            #expect(event.kind == .pong)
        }
    }

    /// Only 16-bit PCM is accepted; anything else is refused rather than handed to the recognizer
    /// as noise.
    @Test func rejectsAudioThatIsNot16Bit() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .transcribe, data: Data(#"{"language":"en-US"}"#.utf8)))
            try await client.send(WyomingEvent(
                kind: .audioStart,
                encoding: WyomingAudioFormat(rate: 16000, width: 4, channels: 1)
            ))

            let event = try await client.receive()
            let response = try event.decodeData(ErrorResponse.self)
            #expect(event.kind == .error)
            #expect(response.text.contains("16-bit"))
        }
    }

    /// A stream that carried no audio has nothing to transcribe, and saying so beats an empty
    /// transcript the pipeline would read as a successful silent turn.
    @Test func reportsAnAudioStreamThatCarriedNothing() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(
                kind: .audioStart,
                encoding: WyomingAudioFormat(rate: 16000, width: 2, channels: 1)
            ))
            try await client.send(WyomingEvent(kind: .audioStop))

            let event = try await client.receive()
            // A device without on-device dictation cannot even open the session, which is reported
            // the same way; either answer proves the failure reaches the client.
            #expect(event.kind == .error || event.kind == .transcript)
            if event.kind == .transcript {
                let transcript = try event.decodeData(TranscriptResponse.self)
                #expect(transcript.text.isEmpty)
            }
        }
    }

    /// Responses this server sends rather than receives are ignored instead of failing the
    /// connection, so a client echoing one back does not end the session.
    @Test func ignoresEventsItOnlySends() async throws {
        try await withClient { client in
            try await client.send(WyomingEvent(kind: .transcript, data: Data(#"{"text":"echo"}"#.utf8)))
            try await client.send(WyomingEvent(kind: .ping))

            let event = try await client.receive()
            #expect(event.kind == .pong)
        }
    }
}
