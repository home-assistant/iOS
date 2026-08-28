import Accelerate
import AVFoundation
import Foundation
import Speech

/// Abstraction over the on-device speech transcriber so the view model can hold a
/// strongly-typed reference without an `@available` guard on the stored property.
@MainActor
protocol SpeechTranscriberProtocol: AnyObject {
    var onTranscriptUpdate: ((String, Bool) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    var onListeningStateChange: ((Bool) -> Void)? { get set }
    /// Normalized microphone input level (0...1) emitted while listening, for UI feedback.
    var onAudioLevelUpdate: ((Float) -> Void)? { get set }
    /// When false, the caller owns the audio session (e.g. CarPlay keeps a .playAndRecord
    /// session active for the whole conversation) and the transcriber must not reconfigure
    /// or deactivate it.
    var managesAudioSession: Bool { get set }
    func startListening() async throws
    func stopListening()
}

/// A speech-to-text transcriber using Apple's Speech framework.
/// Supports real-time transcription with partial results.
@available(iOS 17.0, *)
@MainActor
public final class SpeechTranscriber: ObservableObject, SpeechTranscriberProtocol {
    // MARK: - Types

    public enum TranscriberError: Error, LocalizedError {
        case microphoneNotAuthorized
        case speechRecognitionNotAuthorized
        case notAvailable
        case audioEngineError
        case recognizerError(String)

        public var errorDescription: String? {
            switch self {
            case .microphoneNotAuthorized: return "Microphone permission denied"
            case .speechRecognitionNotAuthorized: return "Speech recognition permission denied"
            case .notAvailable: return "Speech recognition not available"
            case .audioEngineError: return "Audio engine error"
            case let .recognizerError(msg): return msg
            }
        }
    }

    public enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    private enum Constants {
        /// Window of microphone RMS power (dBFS) mapped onto the 0...1 voice level. Matches
        /// `AudioRecorder`: narrow on purpose, so normal speech spans the whole range. It assumes the
        /// session's input dynamics processing is on, which is why `startListening` avoids
        /// `.measurement` mode.
        static let powerFloor: Float = -45
        static let powerCeiling: Float = -15
        /// The tap runs on a real-time audio thread and fires far faster than a screen refresh, so
        /// levels leave it at about 30 Hz instead of once per buffer.
        static let levelInterval: TimeInterval = 1.0 / 30
    }

    // MARK: - Public Properties

    /// The current transcribed text (updates in real-time)
    @Published public private(set) var transcript = ""

    /// Whether the transcriber is currently listening
    @Published public private(set) var isListening = false

    /// Last error message, if any
    @Published public private(set) var errorMessage: String?

    /// The current locale identifier being used for recognition
    public var currentLocale: String {
        speechRecognizer?.locale.identifier ?? "unknown"
    }

    /// Called when transcription updates (partial or final)
    public var onTranscriptUpdate: ((String, Bool) -> Void)?

    /// Called when an error occurs
    public var onError: ((Error) -> Void)?

    /// Called when listening state changes
    public var onListeningStateChange: ((Bool) -> Void)?

    /// Called with a normalized microphone input level (0...1) while listening
    public var onAudioLevelUpdate: ((Float) -> Void)?

    /// Whether this transcriber configures and deactivates the shared audio session itself.
    public var managesAudioSession = true

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private let preferredLocale: Locale?
    private var silenceDetectionTask: Task<Void, Never>?
    private let silenceTimeout: TimeInterval = 1.5
    private let finalGracePeriod: TimeInterval = 0.5
    private var didReportFinalTranscript = false

    // kAFAssistantErrorDomain error codes that indicate a normal session cancellation
    // (internal Apple speech service domain, not publicly declared in the SDK)
    private let kAFAssistantErrorDomain = "kAFAssistantErrorDomain"
    private let kAFAssistantErrorCodeCancelled = 1
    private let kAFAssistantErrorCodeTaskCancelled = 216

    // MARK: - Initialization

    /// Initialize with the device's current locale
    public init() {
        self.preferredLocale = nil
        self.speechRecognizer = createRecognizer(locale: nil)
    }

    /// Initialize with a specific locale
    /// - Parameter locale: The locale to use for speech recognition
    public init(locale: Locale) {
        self.preferredLocale = locale
        self.speechRecognizer = createRecognizer(locale: locale)
    }

    /// Initialize with a locale identifier string
    /// - Parameter localeIdentifier: The locale identifier (e.g., "en-US", "pt-BR")
    public init(localeIdentifier: String) {
        let locale = Locale(identifier: localeIdentifier)
        self.preferredLocale = locale
        self.speechRecognizer = createRecognizer(locale: locale)
    }

    // MARK: - Public Methods

    /// Update the recognizer to use a new locale
    /// - Parameter locale: The new locale to use, or nil for device locale
    public func updateLocale(_ locale: Locale?) {
        speechRecognizer = createRecognizer(locale: locale)
    }

    /// Check current authorization status
    public static var authorizationStatus: AuthorizationStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    /// Request permission for microphone and speech recognition
    /// - Throws: TranscriberError if a required permission is denied
    public func requestPermission() async throws {
        // Request microphone permission
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micStatus else {
            errorMessage = "Microphone permission required"
            throw TranscriberError.microphoneNotAuthorized
        }

        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        if !speechStatus {
            errorMessage = "Speech recognition permission required"
            throw TranscriberError.speechRecognitionNotAuthorized
        }
    }

    /// Start listening and transcribing speech
    /// - Throws: TranscriberError if unable to start
    public func startListening() async throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw TranscriberError.notAvailable
        }

        // Check permissions
        try await requestPermission()

        // Stop any existing session
        stopListening()

        transcript = ""
        didReportFinalTranscript = false
        isListening = true
        errorMessage = nil
        onListeningStateChange?(true)

        // Configure audio session
        if managesAudioSession {
            let audioSession = AVAudioSession.sharedInstance()
            // `.default` rather than `.measurement`, which the framework documents as disabling the
            // dynamics processing on input *and* output. On input that is the gain the level window
            // below is calibrated against, so the orb sits still; and because the mode is a separate
            // session property that `setCategory(.playback)` does not reset, it stays on the session
            // afterwards and is what makes on-device TTS play back quietly. Matching `AudioRecorder`'s
            // category and mode keeps the orb behaving the same whichever transcription path is used.
            // `.duckOthers` is only valid on the playback categories, so it is not passed here either.
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }

        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine else {
            throw TranscriberError.audioEngineError
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw TranscriberError.audioEngineError
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        guard speechRecognizer.supportsOnDeviceRecognition else {
            throw TranscriberError.notAvailable
        }
        recognitionRequest.requiresOnDeviceRecognition = true

        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Capture recognitionRequest locally so the tap closure does not access a @MainActor property
        // from a background thread. The level's rate limit is held the same way, and the tap calls
        // back serially, so it needs no further synchronisation.
        let capturedRequest = recognitionRequest
        var lastLevelEmission: TimeInterval = .zero
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            capturedRequest.append(buffer)

            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastLevelEmission >= Constants.levelInterval else { return }
            lastLevelEmission = now

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = vDSP_Length(buffer.frameLength)
            guard frameCount > 0 else { return }
            var meanSquare: Float = 0
            vDSP_measqv(channelData, 1, &meanSquare, frameCount)
            let decibels = 20 * log10(max(sqrt(meanSquare), .leastNormalMagnitude))
            let range = Constants.powerCeiling - Constants.powerFloor
            let level = max(0, min(1, (decibels - Constants.powerFloor) / range))
            Task { @MainActor in
                self?.onAudioLevelUpdate?(level)
            }
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result, error: error)
            }
        }

        // Start audio engine — clean up on failure so isListening/audio session stay consistent
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopListening()
            throw TranscriberError.audioEngineError
        }
    }

    /// Stop listening and finalize transcription
    public func stopListening() {
        let wasListening = isListening

        silenceDetectionTask?.cancel()
        silenceDetectionTask = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        // Deactivate audio session
        if managesAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        if wasListening {
            onListeningStateChange?(false)
        }
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            transcript = result.bestTranscription.formattedString
            if result.isFinal {
                reportFinalIfNeeded()
            } else {
                onTranscriptUpdate?(transcript, false)
                scheduleSilenceDetection()
            }
        }

        if let error {
            // Ignore cancellation errors from the AFAssistant speech service
            // (e.g. task cancelled after endAudio). Check both domain and code to
            // avoid misclassifying unrelated errors that share the same numeric code.
            let nsError = error as NSError
            let isCancellation = nsError.domain == kAFAssistantErrorDomain &&
                (nsError.code == kAFAssistantErrorCodeTaskCancelled || nsError.code == kAFAssistantErrorCodeCancelled)
            if !isCancellation {
                errorMessage = error.localizedDescription
                onError?(error)
            } else {
                // The recognizer can cancel right after `endAudio()` without ever
                // delivering an `isFinal == true` result (observed on iOS 26 with
                // on-device recognition). Surface the transcript built so far so
                // it isn't silently dropped.
                reportFinalIfNeeded()
            }
            stopListening()
        }

        if result?.isFinal == true {
            stopListening()
        }
    }

    private func reportFinalIfNeeded() {
        guard !didReportFinalTranscript else { return }
        let text = transcript
        guard !text.isEmpty else { return }
        didReportFinalTranscript = true
        onTranscriptUpdate?(text, true)
    }

    private func scheduleSilenceDetection() {
        silenceDetectionTask?.cancel()
        silenceDetectionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.silenceTimeout ?? 1.5) * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.recognitionRequest?.endAudio()

            // Fallback: if the recognizer fails to deliver a final result after
            // `endAudio()`, finalize the transcript ourselves so the assist
            // pipeline still receives the recognized text.
            try? await Task.sleep(nanoseconds: UInt64(self.finalGracePeriod * 1_000_000_000))
            guard !Task.isCancelled, self.isListening, !self.didReportFinalTranscript else { return }
            self.reportFinalIfNeeded()
            self.stopListening()
        }
    }

    private func createRecognizer(locale: Locale?) -> SFSpeechRecognizer? {
        if let locale {
            return SFSpeechRecognizer(locale: locale)
        } else {
            return SFSpeechRecognizer(locale: Locale.current)
        }
    }
}
