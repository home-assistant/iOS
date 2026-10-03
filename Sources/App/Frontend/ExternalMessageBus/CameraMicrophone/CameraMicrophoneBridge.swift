import Foundation
import Shared
import UIKit

final class CameraMicrophoneBridge {
    typealias MakeSession = (_ server: Server, _ cameraEntityId: String) -> CameraMicrophoneSessionProtocol

    var onSessionEnded: ((_ cameraEntityId: String, _ error: CameraMicrophoneError) -> Void)?

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
        completion: @escaping (Result<Void, CameraMicrophoneError>) -> Void
    ) {
        interruptActiveSession()
        let session = makeSession(server, cameraEntityId)
        self.session = session
        session.onEnd = { [weak self, weak session] error in
            guard let self, let session, self.session === session else { return }
            self.session = nil
            onSessionEnded?(session.cameraEntityId, error)
        }
        session.start { [weak self, weak session] result in
            if case .failure = result, let self, let session, self.session === session {
                self.session = nil
            }
            completion(result)
        }
    }

    func stop(cameraEntityId: String?) {
        guard let session, cameraEntityId == nil || cameraEntityId == session.cameraEntityId else { return }
        self.session = nil
        session.stop()
    }

    private func interruptActiveSession() {
        guard let session else { return }
        self.session = nil
        let wasConnected = session.isConnected
        session.stop()
        if wasConnected {
            onSessionEnded?(session.cameraEntityId, .interrupted)
        }
    }
}
