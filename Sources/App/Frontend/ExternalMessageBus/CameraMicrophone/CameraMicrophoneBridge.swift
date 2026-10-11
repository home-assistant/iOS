import Foundation
import Shared
import UIKit

final class CameraMicrophoneBridge {
    typealias MakeSession = (_ server: Server, _ cameraEntityId: String) -> CameraMicrophoneSessionProtocol

    var onSessionEnded: ((_ sessionId: String) -> Void)?

    var activeCameraEntityId: String? {
        session?.cameraEntityId
    }

    private let notificationCenter: NotificationCenter
    private let makeSession: MakeSession
    private var session: CameraMicrophoneSessionProtocol?
    private var backgroundObserver: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        makeSession: @escaping MakeSession = { CameraMicrophoneSession(server: $0, cameraEntityId: $1) }
    ) {
        self.notificationCenter = notificationCenter
        self.makeSession = makeSession
        self.backgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.interruptActiveSession()
        }
    }

    deinit {
        if let backgroundObserver {
            notificationCenter.removeObserver(backgroundObserver)
        }
        session?.stop()
    }

    func start(
        cameraEntityId: String,
        server: Server,
        completion: @escaping (Result<String, CameraMicrophoneError>) -> Void
    ) {
        interruptActiveSession()
        let session = makeSession(server, cameraEntityId)
        self.session = session
        session.onEnd = { [weak self, weak session] _ in
            guard let self, let session, self.session === session else { return }
            self.session = nil
            if let sessionId = session.sessionId {
                onSessionEnded?(sessionId)
            }
        }
        session.start { [weak self, weak session] result in
            if case .failure = result, let self, let session, self.session === session {
                self.session = nil
            }
            completion(result)
        }
    }

    func stop(sessionId: String) {
        guard let session, session.sessionId == sessionId else { return }
        self.session = nil
        session.stop()
    }

    func stopActiveSession() {
        guard let session else { return }
        self.session = nil
        session.stop()
    }

    private func interruptActiveSession() {
        guard let session else { return }
        self.session = nil
        let wasConnected = session.isConnected
        session.stop()
        if wasConnected, let sessionId = session.sessionId {
            onSessionEnded?(sessionId)
        }
    }
}
