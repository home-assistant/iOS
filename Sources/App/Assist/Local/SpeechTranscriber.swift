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

    /// Bumped by every `stopListening()`. A setup still running when it fires belongs to the session
    /// that was stopped, so it unwinds the engine it just built instead of publishing it over the
    /// state that stop has already reset.
    private var sessionGeneration = 0

    /// Everything that touches the audio session, the audio engine or the recognizer's on-device
    /// support runs here. All of it blocks: `setCategory`/`setActive` and
    /// `supportsOnDeviceRecognition` are synchronous XPC round trips to the audio and speech
    /// daemons, and `AVAudioEngine.start()`/`stop()` wait on the media server. Run from the main
    /// thread they cost the runloop around 300ms every time Assist starts listening, which the
    /// system reports as a hang; `AudioRecorder` keeps its capture session off the main thread for
    /// the same reason. Serial, so a stop can never overtake the start it belongs to.
    private let sessionQueue = DispatchQueue(label: "assist-speech-transcriber-session", qos: .userInitiated)

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

        // Past this point the transcriber counts as listening, so every failure has to unwind
        // through `stopListening()`. Leaving `isListening` set would make the *next* start report a
        // stale stop to the caller while it is still setting the new session up.
        do {
            try await startRecognition(with: speechRecognizer)
        } catch {
            stopListening()
            throw error
        }
    }

    /// The audio session, engine and recognition task built for one listening session. Assembled on
    /// `sessionQueue`, then either published to the transcriber or torn down again.
    private struct RecognitionSession {
        let engine: AVAudioEngine
        let request: SFSpeechAudioBufferRecognitionRequest
        let task: SFSpeechRecognitionTask
    }

    /// Configures the audio session, engine and recognition task for a session the caller has
    /// already marked as listening, and which it unwinds if this throws. The blocking part runs on
    /// `sessionQueue` and only its result is published back here.
    private func startRecognition(with speechRecognizer: SFSpeechRecognizer) async throws {
        let generation = sessionGeneration
        let configuresAudioSession = managesAudioSession

        // Both callbacks reach the transcriber's own closures through `self` when they fire rather
        // than capturing them by value, so a caller that reassigns them mid-session still gets them.
        let onLevel: (Float) -> Void = { [weak self] level in
            Task { @MainActor in self?.onAudioLevelUpdate?(level) }
        }
        let onResult: (SFSpeechRecognitionResult?, Error?) -> Void = { [weak self] result, error in
            Task { @MainActor in self?.handleRecognitionResult(result, error: error) }
        }

        let session = try await onSessionQueue {
            try Self.makeRecognitionSession(
                recognizer: speechRecognizer,
                configuresAudioSession: configuresAudioSession,
                onLevel: onLevel,
                onResult: onResult
            )
        }

        // `stopListening()` stays synchronous, so it can land while the engine is still starting up.
        // The session it stopped is this one: publish nothing and unwind what was just built, or the
        // microphone would stay open with no reference left to close it.
        guard generation == sessionGeneration else {
            tearDown(
                engine: session.engine,
                request: session.request,
                task: session.task,
                deactivatesAudioSession: configuresAudioSession
            )
            return
        }

        audioEngine = session.engine
        recognitionRequest = session.request
        recognitionTask = session.task
    }

    /// Builds one listening session. Every call in here blocks, so it only ever runs on
    /// `sessionQueue`, which is also why it takes everything it needs as arguments instead of
    /// reading the transcriber's main-actor state.
    private nonisolated static func makeRecognitionSession(
        recognizer: SFSpeechRecognizer,
        configuresAudioSession: Bool,
        onLevel: @escaping (Float) -> Void,
        onResult: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) throws -> RecognitionSession {
        if configuresAudioSession {
            let audioSession = AVAudioSession.sharedInstance()
            // `.default` rather than `.measurement`, which the framework documents as disabling the
            // dynamics processing on input *and* output. On input that is the gain the level window
            // below is calibrated against, so the orb sits still; and because the mode is a separate
            // session property that `setCategory(.playback)` does not reset, it stays on the session
            // afterwards and is what makes on-device TTS play back quietly. Matching `AudioRecorder`'s
            // category and mode keeps the orb behaving the same whichever transcription path is used.
            // `.duckOthers` is only valid on the playback categories, so it is not passed here either.
            // Deactivated first, like `AudioRecorder` and `AudioPlayer` do, so the category is not
            // switched underneath a session another Assist component left active. A failure here is
            // not fatal: the category still has to be set, or recording starts on whatever the last
            // playback left behind.
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.record, mode: .default)
            // No `.notifyOthersOnDeactivation` here: the framework documents that option as valid
            // only when deactivating.
            try audioSession.setActive(true)
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriberError.notAvailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = true

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // The tap runs on a real-time audio thread, so it holds the request directly instead of
        // reaching for a @MainActor property, and keeps the level's rate limit in the closure. Taps
        // call back serially, so neither needs further synchronisation.
        var lastLevelEmission: TimeInterval = .zero
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)

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
            onLevel(max(0, min(1, (decibels - Constants.powerFloor) / range)))
        }

        let task = recognizer.recognitionTask(with: request, resultHandler: onResult)

        engine.prepare()
        do {
            try engine.start()
        } catch {
            // Nothing has been handed back yet, so this failure has to release the microphone, the
            // recognizer and the session itself.
            inputNode.removeTap(onBus: 0)
            request.endAudio()
            task.cancel()
            if configuresAudioSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            throw TranscriberError.audioEngineError
        }

        return RecognitionSession(engine: engine, request: request, task: task)
    }

    /// Runs blocking audio work on `sessionQueue`, suspending the main actor instead of blocking it.
    private func onSessionQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        let queue = sessionQueue
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result(catching: work))
            }
        }
    }

    /// Releases the microphone, the recognizer and — when this transcriber owns it — the audio
    /// session. Dispatched rather than run inline because stopping the engine and deactivating the
    /// session block on the media and audio daemons exactly like starting them does. The queue is
    /// serial, so this always lands behind the setup it is unwinding.
    private func tearDown(
        engine: AVAudioEngine?,
        request: SFSpeechAudioBufferRecognitionRequest?,
        task: SFSpeechRecognitionTask?,
        deactivatesAudioSession: Bool
    ) {
        sessionQueue.async {
            engine?.stop()
            engine?.inputNode.removeTap(onBus: 0)
            request?.endAudio()
            task?.cancel()
            if deactivatesAudioSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    /// Stop listening and finalize transcription
    public func stopListening() {
        let wasListening = isListening

        // Marks any setup still in flight as belonging to the session being stopped.
        sessionGeneration &+= 1

        silenceDetectionTask?.cancel()
        silenceDetectionTask = nil

        let engine = audioEngine
        let request = recognitionRequest
        let task = recognitionTask
        let deactivatesAudioSession = managesAudioSession

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        tearDown(
            engine: engine,
            request: request,
            task: task,
            deactivatesAudioSession: deactivatesAudioSession
        )

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
