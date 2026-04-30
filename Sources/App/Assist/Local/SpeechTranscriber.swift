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
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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
        // from a background thread.
        let capturedRequest = recognitionRequest
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            capturedRequest.append(buffer)
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if wasListening {
            onListeningStateChange?(false)
        }
    }

    /// Get list of locales that support on-device speech recognition
    public static var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales()
            .filter { SFSpeechRecognizer(locale: $0)?.supportsOnDeviceRecognition == true }
            .sorted { $0.identifier < $1.identifier }
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
