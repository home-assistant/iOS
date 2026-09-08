import Foundation
import Network
import Shared

/// Serves one connected Wyoming client.
///
/// Home Assistant's `wyoming` integration opens a fresh connection for each transcription and each
/// synthesis, so in practice a connection does one job and closes — but the protocol allows several
/// in a row, and the state machine below does not assume otherwise.
///
/// Reads run as one sequential `await` loop rather than through the connection's callbacks. Audio
/// only makes sense in the order it was sent, and hopping every callback onto this actor with its
/// own `Task` would give up that ordering.
actor WyomingConnection {
    private enum Constants {
        static let readSize = 64 * 1024
        /// Roughly 90 ms of speech per `audio-chunk` at the rates the synthesiser produces: small
        /// enough that a long answer is not one enormous write, large enough to keep the framing
        /// overhead irrelevant.
        static let synthesizedChunkBytes = 4096
    }

    /// `transcribe` names the language Home Assistant's pipeline is configured for.
    private struct TranscribeRequest: Decodable {
        let language: String?
    }

    private struct SynthesizeRequest: Decodable {
        struct Voice: Decodable {
            /// The voice id, which is the `AVSpeechSynthesisVoice` identifier this server advertised.
            let name: String?
            let language: String?
        }

        let text: String
        let voice: Voice?
    }

    private struct TranscriptResponse: Encodable {
        let text: String
    }

    private struct ErrorResponse: Encodable {
        let text: String
        let code: String
    }

    private let connection: NWConnection
    private let queue: DispatchQueue
    /// Used when the client transcribes without naming a language, which the protocol allows.
    private let fallbackLocale: Locale
    private let makeRecognizer: WyomingRecognizerFactory
    private let synthesizer = WyomingSpeechSynthesizer()

    private var buffer = Data()
    private var requestedLanguage: String?
    private var recognition: WyomingSpeechRecognitionSession?

    init(
        connection: NWConnection,
        queue: DispatchQueue,
        fallbackLocale: Locale,
        makeRecognizer: @escaping WyomingRecognizerFactory
    ) {
        self.connection = connection
        self.queue = queue
        self.fallbackLocale = fallbackLocale
        self.makeRecognizer = makeRecognizer
    }

    /// Reads and answers events until the client hangs up or the task is cancelled.
    func run() async {
        connection.stateUpdateHandler = { state in
            if case let .failed(error) = state {
                Current.Log.error("Wyoming connection failed: \(error)")
            }
        }
        connection.start(queue: queue)

        do {
            while !Task.isCancelled {
                let chunk = try await receive()
                buffer.append(chunk)
                while let event = try WyomingEventCodec.decode(from: &buffer) {
                    await handle(event)
                }
            }
        } catch let error as WyomingProtocolError where error == .connectionClosed {
            // The expected end of every Home Assistant request.
        } catch {
            Current.Log.error("Wyoming connection ended: \(error)")
        }

        close()
    }

    func close() {
        let session = recognition
        recognition = nil
        Task { @MainActor in session?.cancel() }
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    // MARK: - Event handling

    private func handle(_ event: WyomingEvent) async {
        do {
            try await process(event)
        } catch {
            Current.Log.error("Wyoming: failed to handle \(event.type): \(error)")
            await cancelRecognition()
            await sendError(error)
        }
    }

    private func process(_ event: WyomingEvent) async throws {
        guard let kind = event.kind else { return }
        switch kind {
        case .describe:
            try await send(WyomingEvent(kind: .info, encoding: WyomingServiceCatalog.info()))
        case .ping:
            try await send(WyomingEvent(kind: .pong, data: event.data))
        case .transcribe:
            requestedLanguage = try? event.decodeData(TranscribeRequest.self).language
        case .audioStart:
            try await startRecognition(format: event.decodeData())
        case .audioChunk:
            try await appendAudio(event)
        case .audioStop:
            try await finishRecognition()
        case .synthesize:
            try await synthesize(event.decodeData())
        case .info, .transcript, .pong, .error:
            // Responses this server sends rather than receives; a client echoing one back is not
            // an error worth failing the connection over.
            break
        }
    }

    private func startRecognition(format: WyomingAudioFormat) async throws {
        await cancelRecognition()
        let locale = await WyomingServiceCatalog.resolveLocale(for: requestedLanguage, fallback: fallbackLocale)
        let makeRecognizer = makeRecognizer
        recognition = try await MainActor.run {
            try WyomingSpeechRecognitionSession(format: format) { try makeRecognizer(locale) }
        }
    }

    private func appendAudio(_ event: WyomingEvent) async throws {
        // Every chunk repeats the format, so a client that skipped `audio-start` still describes
        // what it is sending and does not have to be turned away.
        if recognition == nil {
            try await startRecognition(format: event.decodeData())
        }
        guard let recognition, let payload = event.payload else { return }
        await MainActor.run { recognition.append(payload) }
    }

    private func finishRecognition() async throws {
        guard let recognition else { return }
        self.recognition = nil
        let text = try await recognition.finish()
        try await send(WyomingEvent(kind: .transcript, encoding: TranscriptResponse(text: text)))
    }

    private func cancelRecognition() async {
        guard let recognition else { return }
        self.recognition = nil
        await MainActor.run { recognition.cancel() }
    }

    private func synthesize(_ request: SynthesizeRequest) async throws {
        let output = try await synthesizer.synthesize(
            text: request.text,
            voiceIdentifier: request.voice?.name,
            language: request.voice?.language
        )

        try await send(WyomingEvent(kind: .audioStart, encoding: output.format))
        var offset = output.audio.startIndex
        while offset < output.audio.endIndex {
            let end = output.audio.index(
                offset,
                offsetBy: Constants.synthesizedChunkBytes,
                limitedBy: output.audio.endIndex
            ) ?? output.audio.endIndex
            try await send(WyomingEvent(
                kind: .audioChunk,
                encoding: output.format,
                payload: Data(output.audio[offset ..< end])
            ))
            offset = end
        }
        try await send(WyomingEvent(kind: .audioStop))
    }

    /// Reports a failure the way the protocol expects, so the client stops waiting instead of
    /// timing out. A send failure here means the client is already gone.
    private func sendError(_ error: Error) async {
        let response = ErrorResponse(
            text: error.localizedDescription,
            code: String(describing: type(of: error))
        )
        try? await send(WyomingEvent(kind: .error, encoding: response))
    }

    // MARK: - Transport

    private func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection
                .receive(
                    minimumIncompleteLength: 1,
                    maximumLength: Constants.readSize
                ) { content, _, isComplete, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let content, !content.isEmpty {
                        continuation.resume(returning: content)
                    } else if isComplete {
                        continuation.resume(throwing: WyomingProtocolError.connectionClosed)
                    } else {
                        continuation.resume(returning: Data())
                    }
                }
        }
    }

    private func send(_ event: WyomingEvent) async throws {
        let data = try WyomingEventCodec.encode(event)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
