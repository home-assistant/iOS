import AVFoundation
import Foundation
import Shared

final class MicrophoneRecordingSession: MicrophoneRecordingSessionProtocol {
    /// The whole recording crosses the external bus as base64 when it is collected, so it is capped.
    static let maximumDuration: TimeInterval = 300

    private enum State {
        case idle
        case starting
        case recording
        case stopped
    }

    let sessionId: String
    var onEnd: ((MicrophoneRecordingStopReason) -> Void)?

    var isRecording: Bool {
        state == .recording
    }

    private let fileURL: URL
    private let notificationCenter: NotificationCenter
    private let requestMicrophonePermission: () async -> Bool
    private let prepareAudioSession: () throws -> Void
    private let makeRecorder: (URL) throws -> MicrophoneAudioRecorderProtocol

    private var state: State = .idle
    private var startCompletion: ((Result<String, MicrophoneRecordingError>) -> Void)?
    private var recorder: MicrophoneAudioRecorderProtocol?
    private var interruptionObserver: NSObjectProtocol?

    init(
        sessionId: String = UUID().uuidString,
        directory: URL = FileManager.default.temporaryDirectory,
        notificationCenter: NotificationCenter = .default,
        requestMicrophonePermission: @escaping () async -> Bool = MicrophoneRecordingSession.requestPermission,
        prepareAudioSession: @escaping () throws -> Void = MicrophoneRecordingSession.prepareSharedAudioSession,
        makeRecorder: @escaping (URL) throws -> MicrophoneAudioRecorderProtocol = {
            try MicrophoneAudioRecorder(fileURL: $0)
        }
    ) {
        self.sessionId = sessionId
        self.fileURL = directory.appendingPathComponent("microphone-recording-\(sessionId).wav")
        self.notificationCenter = notificationCenter
        self.requestMicrophonePermission = requestMicrophonePermission
        self.prepareAudioSession = prepareAudioSession
        self.makeRecorder = makeRecorder
    }

    deinit {
        discard()
    }

    func start(completion: @escaping (Result<String, MicrophoneRecordingError>) -> Void) {
        guard state == .idle else {
            completion(.failure(.interrupted))
            return
        }
        state = .starting
        startCompletion = completion
        Current.Log.info("Starting microphone recording \(sessionId)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await requestMicrophonePermission()
            guard state == .starting else { return }
            guard granted else {
                failStart(with: .microphoneDenied)
                return
            }
            beginRecording()
        }
    }

    func finish(completion: @escaping (Result<MicrophoneRecording, MicrophoneRecordingError>) -> Void) {
        stop()
        // Holds on to the session until the file is read, releasing it discards the file.
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = Result { try MicrophoneRecording(sessionId: sessionId, fileURL: fileURL) }
                .mapError { error -> MicrophoneRecordingError in
                    Current.Log.error("Failed to read microphone recording \(sessionId): \(error)")
                    return .recordingFailed
                }
            try? FileManager.default.removeItem(at: fileURL)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func discard() {
        stop()
        try? FileManager.default.removeItem(at: fileURL)
    }

    func stop() {
        switch state {
        case .starting:
            state = .stopped
            resolveStart(.failure(.interrupted))
        case .recording:
            stopRecorder()
        case .idle, .stopped:
            state = .stopped
        }
    }

    private func beginRecording() {
        let recorder: MicrophoneAudioRecorderProtocol
        do {
            try prepareAudioSession()
            recorder = try makeRecorder(fileURL)
        } catch {
            Current.Log.error("Failed to set up microphone recording \(sessionId): \(error)")
            failStart(with: .recordingFailed)
            return
        }
        recorder.onFinish = { [weak self] successfully in
            self?.end(with: successfully ? .maxDuration : .failed)
        }
        guard recorder.record(forDuration: Self.maximumDuration) else {
            Current.Log.error("Microphone recording \(sessionId) failed to start")
            recorder.onFinish = nil
            failStart(with: .recordingFailed)
            return
        }
        self.recorder = recorder
        state = .recording
        observeInterruptions()
        Current.Log.info("Microphone recording \(sessionId) started")
        resolveStart(.success(sessionId))
    }

    private func observeInterruptions() {
        interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            guard type == .began else { return }
            self?.end(with: .interrupted)
        }
    }

    private func end(with reason: MicrophoneRecordingStopReason) {
        guard state == .recording else { return }
        stopRecorder()
        Current.Log.info("Microphone recording \(sessionId) ended: \(reason.rawValue)")
        onEnd?(reason)
    }

    private func stopRecorder() {
        state = .stopped
        if let interruptionObserver {
            notificationCenter.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        recorder?.onFinish = nil
        recorder?.stop()
        recorder = nil
    }

    private func failStart(with error: MicrophoneRecordingError) {
        state = .stopped
        try? FileManager.default.removeItem(at: fileURL)
        resolveStart(.failure(error))
    }

    private func resolveStart(_ result: Result<String, MicrophoneRecordingError>) {
        let completion = startCompletion
        startCompletion = nil
        completion?(result)
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Leaves the shared audio session active afterwards, the web view plays through it too.
    static func prepareSharedAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true)
    }
}
