import Foundation
import Shared
import UIKit

/// Records the microphone for the frontend, which has no microphone of its own without a secure context.
///
/// One recording runs at a time. A recording the app ends by itself is kept until the frontend collects it
/// with `stop(sessionId:completion:)`, so the audio is handed over the same way whichever side stopped it.
final class MicrophoneRecordingBridge {
    typealias MakeSession = () -> MicrophoneRecordingSessionProtocol

    var onSessionEnded: ((_ sessionId: String, _ reason: MicrophoneRecordingStopReason) -> Void)?

    var activeSessionId: String? {
        session?.sessionId
    }

    private let notificationCenter: NotificationCenter
    private let makeSession: MakeSession
    private var session: MicrophoneRecordingSessionProtocol?
    private var endedSessions: [String: MicrophoneRecordingSessionProtocol] = [:]
    private var backgroundObserver: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        makeSession: @escaping MakeSession = { MicrophoneRecordingSession() }
    ) {
        self.notificationCenter = notificationCenter
        self.makeSession = makeSession
        self.backgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endActiveSession(reason: .background)
        }
    }

    deinit {
        if let backgroundObserver {
            notificationCenter.removeObserver(backgroundObserver)
        }
        discardAll()
    }

    func start(completion: @escaping (Result<String, MicrophoneRecordingError>) -> Void) {
        endActiveSession(reason: .replaced)
        let session = makeSession()
        self.session = session
        session.onEnd = { [weak self, weak session] reason in
            guard let self, let session, self.session === session else { return }
            self.session = nil
            endedSessions[session.sessionId] = session
            onSessionEnded?(session.sessionId, reason)
        }
        session.start { [weak self, weak session] result in
            if case .failure = result, let self, let session, self.session === session {
                self.session = nil
            }
            completion(result)
        }
    }

    /// Stops the recording if it is still running and hands it over, whichever side ended it.
    func stop(
        sessionId: String,
        completion: @escaping (Result<MicrophoneRecording, MicrophoneRecordingError>) -> Void
    ) {
        let target: MicrophoneRecordingSessionProtocol
        if let session, session.isRecording, session.sessionId == sessionId {
            self.session = nil
            target = session
        } else if let ended = endedSessions.removeValue(forKey: sessionId) {
            target = ended
        } else {
            completion(.failure(.sessionNotFound))
            return
        }
        target.finish(completion: completion)
    }

    /// Throws away every recording, for a frontend page that is gone and will never collect them.
    func discardAll() {
        let sessions = [session].compactMap { $0 } + Array(endedSessions.values)
        session = nil
        endedSessions.removeAll()
        for session in sessions {
            session.discard()
        }
    }

    private func endActiveSession(reason: MicrophoneRecordingStopReason) {
        guard let session else { return }
        self.session = nil
        guard session.isRecording else {
            // Still starting, its start is answered as interrupted.
            session.discard()
            return
        }
        session.stop()
        endedSessions[session.sessionId] = session
        onSessionEnded?(session.sessionId, reason)
    }
}
