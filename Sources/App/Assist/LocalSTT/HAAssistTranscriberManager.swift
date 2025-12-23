import AVFoundation
import Foundation
import Observation
import Shared
import Speech
import SwiftUI

@available(iOS 26.0, *)
@Observable
@MainActor
final class HAAssistTranscriberManager {
    // MARK: - Public Properties

    /// Current state of the transcriber
    private(set) var state: HAAssistTranscriptionState = .notTranscribing

    /// Latest transcription result (combines finalized + volatile)
    private(set) var lastTranscription: String = ""

    /// Progress for model download (if needed)
    private(set) var downloadProgress: Progress?

    // MARK: - Configuration

    /// Silence duration before auto-stopping (default: 2 seconds)
    var silenceThreshold: Measurement<UnitDuration> = .init(value: 2.0, unit: .seconds) {
        didSet {
            transcriber?.silenceThreshold = silenceThreshold
        }
    }

    /// Whether to automatically stop when silence is detected (default: true)
    var autoStopEnabled: Bool = true {
        didSet {
            transcriber?.autoStopEnabled = autoStopEnabled
        }
    }

    // MARK: - Private Properties

    private var transcriber: HAAssistTranscriber?
    private var audioEngine: AVAudioEngine?
    private var recordingTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {}

    // MARK: - Cleanup

    deinit {
        // Capture properties in a detached task since deinit cannot be MainActor-isolated
        // We must assume we're on the MainActor since this is a @MainActor class
        MainActor.assumeIsolated {
            let task = recordingTask
            let engine = audioEngine
            let transcriber = transcriber

            task?.cancel()
            engine?.stop()

            Task {
                try? await transcriber?.finishTranscribing()
                await transcriber?.releaseLocales()
            }
        }
    }

    // MARK: - Public Methods

    /// Start transcription with automatic silence detection
    func start() async throws {
        guard state == .notTranscribing else {
            print("⚠️ Transcriber is already running")
            return
        }

        // Request microphone permission
        let authorized = await requestMicrophonePermission()
        guard authorized else {
            throw NSError(
                domain: "HAAssistTranscriber",
                code: 1,

                userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]
            )
        }

        state = .transcribing

        // Setup transcriber
        let transcriber = HAAssistTranscriber()
        transcriber.silenceThreshold = silenceThreshold
        transcriber.autoStopEnabled = autoStopEnabled

        // Setup speech ended callback
        transcriber.onSpeechEnded = { [weak self] in
            Task { @MainActor [weak self] in
                print("🛑 Speech ended via silence detection")
                try? await self?.stop()
            }
        }

        try await transcriber.setUpTranscriber()

        self.transcriber = transcriber
        downloadProgress = transcriber.downloadProgress

        // Setup audio engine
        try await startAudioEngine()

        // Start observing transcription changes
        startObservingTranscription()
    }

    /// Stop transcription manually
    func stop() async throws {
        guard state == .transcribing else { return }

        state = .notTranscribing

        // Stop audio recording
        recordingTask?.cancel()
        recordingTask = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        // Finalize transcription
        try await transcriber?.finishTranscribing()

        print("✅ Transcription stopped")
    }

    /// Reset transcription text
    func reset() {
        lastTranscription = ""
        transcriber?.finalizedTranscript = ""
        transcriber?.volatileTranscript = ""
    }

    // MARK: - Private Methods

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startAudioEngine() async throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard let transcriber,
              let analyzerFormat = transcriber.analyzerFormat else {
            throw HAAssistTranscriptionError.failedToSetupRecognitionStream
        }

        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.transcriber?.streamAudioToTranscriber(buffer)
                } catch {
                    print("❌ Error streaming audio: \(error)")
                }
            }
        }

        // Start the engine
        try audioEngine.start()
        self.audioEngine = audioEngine

        print("🎤 Audio engine started")
    }

    private func startObservingTranscription() {
        recordingTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))

                guard let transcriber else { continue }

                // Combine finalized and volatile transcripts
                let finalized = String(transcriber.finalizedTranscript.characters)
                let volatile = String(transcriber.volatileTranscript.characters)

                lastTranscription = finalized + volatile
            }
        }
    }
}
