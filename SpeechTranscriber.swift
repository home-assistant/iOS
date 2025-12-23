import AVFoundation
import Speech

/// A class that manages speech transcription using Apple's SpeechTranscriber API.
/// Automatically detects when the user has finished speaking.
@available(iOS 18.0, *)
@MainActor
final class SpeechTranscriber: ObservableObject {
    // MARK: - Published Properties

    /// The current transcription text
    @Published private(set) var transcription: String = ""

    /// Whether the transcriber is currently listening
    @Published private(set) var isListening: Bool = false

    /// The current authorization status
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    /// Any error that occurred during transcription
    @Published private(set) var error: Error?

    // MARK: - Private Properties

    private var speechTranscriber: Speech.SpeechTranscriber?
    private var transcriptionTask: Task<Void, Never>?
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization

    init() {
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Public Methods

    /// Requests authorization to use speech recognition
    func requestAuthorization() async {
        let status = await SFSpeechRecognizer.requestAuthorization()
        authorizationStatus = status
    }

    /// Starts listening and transcribing speech
    /// - Parameter locale: The locale for speech recognition (defaults to device locale)
    func startListening(locale: Locale = .current) async throws {
        // Check authorization
        guard authorizationStatus == .authorized else {
            throw TranscriberError.notAuthorized
        }

        // Stop any existing transcription
        if isListening {
            await stopListening()
        }

        // Reset state
        transcription = ""
        error = nil
        isListening = true

        // Request audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create the speech transcriber
        let transcriber = Speech.SpeechTranscriber(locale: locale)
        speechTranscriber = transcriber

        // Start transcription task
        transcriptionTask = Task {
            do {
                // Get the audio input
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)

                // Create transcription session
                let session = transcriber.addsPunctuation().onAudioPacketAvailable { [weak self] _ in
                    // Audio packet callback if needed for visualization
                }

                // Install tap on audio engine
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                    guard let self else { return }

                    // Send audio to transcriber
                    Task { @MainActor in
                        try? await self.speechTranscriber?.transcribe(audioBuffer: buffer)
                    }
                }

                // Start the audio engine
                audioEngine.prepare()
                try audioEngine.start()

                // Process transcription results
                for try await result in transcriber.transcribedResults() {
                    await handleTranscriptionResult(result)
                }

            } catch {
                await handleError(error)
            }
        }
    }

    /// Stops listening and transcribing
    func stopListening() async {
        isListening = false

        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Finish transcription
        try? await speechTranscriber?.finishTranscription()

        // Cancel task
        transcriptionTask?.cancel()
        transcriptionTask = nil
        speechTranscriber = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private Methods

    private func handleTranscriptionResult(_ result: SFTranscriptionResult) {
        // Update transcription
        transcription = result.bestTranscription.formattedString

        // Check if speech has finished
        if result.isFinal {
            Task {
                await stopListening()
            }
        } else if result.bestTranscription.segments.last?.confidence ?? 0 > 0.5 {
            // If we have high confidence and a pause, consider stopping
            // This helps auto-detect when the user is done speaking
            let lastSegmentTimestamp = result.bestTranscription.segments.last?.timestamp ?? 0
            let duration = result.bestTranscription.segments.last?.duration ?? 0

            // You can adjust this threshold for pause detection
            if duration > 2.0 { // 2 second pause
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    if self.isListening {
                        await stopListening()
                    }
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        self.error = error
        Task {
            await stopListening()
        }
    }

    // MARK: - Error Types

    enum TranscriberError: LocalizedError {
        case notAuthorized
        case audioEngineFailure
        case transcriptionFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition is not authorized. Please enable it in Settings."
            case .audioEngineFailure:
                return "Failed to start audio engine."
            case .transcriptionFailed:
                return "Speech transcription failed."
            }
        }
    }
}
