import Foundation
import Speech
import AVFoundation

/// A speech-to-text transcriber using Apple's Speech framework.
/// Supports real-time transcription with partial results.
@available(iOS 17.0, *)
@MainActor
public final class SpeechTranscriber: ObservableObject {

    // MARK: - Types

    public enum TranscriberError: Error, LocalizedError {
        case notAuthorized
        case notAvailable
        case audioEngineError
        case recognizerError(String)

        public var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Microphone permission denied"
            case .notAvailable: return "Speech recognition not available"
            case .audioEngineError: return "Audio engine error"
            case .recognizerError(let msg): return msg
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
    @Published public var onTranscriptUpdate: ((String, Bool) -> Void)?

    /// Called when an error occurs
    @Published public var onError: ((Error) -> Void)?

    /// Called when listening state changes
    @Published public var onListeningStateChange: ((Bool) -> Void)?

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private let preferredLocale: Locale?

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
    /// - Returns: True if both permissions are granted
    @discardableResult
    public func requestPermission() async -> Bool {
        // Request microphone permission
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micStatus else {
            errorMessage = "Microphone permission required"
            return false
        }

        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        if !speechStatus {
            errorMessage = "Speech recognition permission required"
        }

        return speechStatus
    }

    /// Start listening and transcribing speech
    /// - Throws: TranscriberError if unable to start
    public func startListening() async throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw TranscriberError.notAvailable
        }

        // Check permissions
        guard await requestPermission() else {
            throw TranscriberError.notAuthorized
        }

        // Stop any existing session
        stopListening()

        transcript = ""
        isListening = true
        errorMessage = nil
        onListeningStateChange?(true)

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw TranscriberError.audioEngineError
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriberError.audioEngineError
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                    self.onTranscriptUpdate?(self.transcript, result.isFinal)
                }

                if let error = error {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.code != 216 && nsError.code != 1 { // cancellation codes
                        self.errorMessage = error.localizedDescription
                        self.onError?(error)
                    }
                    self.stopListening()
                }

                if result?.isFinal == true {
                    self.stopListening()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Stop listening and finalize transcription
    public func stopListening() {
        let wasListening = isListening

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

    /// Get list of available locales for speech recognition
    public static var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales().sorted {
            $0.identifier < $1.identifier
        }
    }

    // MARK: - Private Methods

    private func createRecognizer(locale: Locale?) -> SFSpeechRecognizer? {
        let recognizer: SFSpeechRecognizer?

        if let locale = locale {
            recognizer = SFSpeechRecognizer(locale: locale)
        } else {
            recognizer = SFSpeechRecognizer(locale: Locale.current)
        }

        // Fallback if selected locale not available
        if let r = recognizer, r.isAvailable {
            return r
        } else {
            return SFSpeechRecognizer()
        }
    }
}
