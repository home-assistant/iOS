@testable import HomeAssistant

final class FakeMicrophoneRecordingSession: MicrophoneRecordingSessionProtocol {
    let sessionId: String
    var isRecording = false
    var onEnd: ((MicrophoneRecordingStopReason) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var finishCount = 0
    private(set) var discardCount = 0
    private var startCompletion: ((Result<String, MicrophoneRecordingError>) -> Void)?
    private var finishCompletion: ((Result<MicrophoneRecording, MicrophoneRecordingError>) -> Void)?

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    func start(completion: @escaping (Result<String, MicrophoneRecordingError>) -> Void) {
        startCount += 1
        startCompletion = completion
    }

    func stop() {
        stopCount += 1
        isRecording = false
        resolveStart(.failure(.interrupted))
    }

    func finish(completion: @escaping (Result<MicrophoneRecording, MicrophoneRecordingError>) -> Void) {
        finishCount += 1
        isRecording = false
        finishCompletion = completion
    }

    func discard() {
        discardCount += 1
        isRecording = false
        resolveStart(.failure(.interrupted))
    }

    func record() {
        isRecording = true
        resolveStart(.success(sessionId))
    }

    func fail(_ error: MicrophoneRecordingError) {
        resolveStart(.failure(error))
    }

    func end(_ reason: MicrophoneRecordingStopReason) {
        isRecording = false
        onEnd?(reason)
    }

    func deliver(_ result: Result<MicrophoneRecording, MicrophoneRecordingError>) {
        let completion = finishCompletion
        finishCompletion = nil
        completion?(result)
    }

    private func resolveStart(_ result: Result<String, MicrophoneRecordingError>) {
        let completion = startCompletion
        startCompletion = nil
        completion?(result)
    }
}
