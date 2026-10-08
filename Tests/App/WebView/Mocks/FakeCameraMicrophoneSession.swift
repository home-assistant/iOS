@testable import HomeAssistant
import Shared

final class FakeCameraMicrophoneSession: CameraMicrophoneSessionProtocol {
    let cameraEntityId: String
    let server: Server
    var sessionId: String?
    var isConnected = false
    var onEnd: ((CameraMicrophoneError) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var microphoneEnabledChanges: [Bool] = []
    private var startCompletion: ((Result<String, CameraMicrophoneError>) -> Void)?

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    func start(completion: @escaping (Result<String, CameraMicrophoneError>) -> Void) {
        startCount += 1
        startCompletion = completion
    }

    func stop() {
        stopCount += 1
        isConnected = false
        resolveStart(.failure(.interrupted))
    }

    func setMicrophoneEnabled(_ enabled: Bool) {
        microphoneEnabledChanges.append(enabled)
    }

    func connect(sessionId: String) {
        self.sessionId = sessionId
        isConnected = true
        resolveStart(.success(sessionId))
    }

    func fail(_ error: CameraMicrophoneError) {
        resolveStart(.failure(error))
    }

    func end(_ error: CameraMicrophoneError) {
        isConnected = false
        onEnd?(error)
    }

    private func resolveStart(_ result: Result<String, CameraMicrophoneError>) {
        let completion = startCompletion
        startCompletion = nil
        completion?(result)
    }
}
