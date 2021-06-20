import Foundation
import Shared
import HAKit

class NotificationManagerLocalPushInterfaceDirect: NotificationManagerLocalPushInterface {
    var status: NotificationManagerLocalPushStatus {
        .allowed(localPushManager.state)
    }

    let localPushManager: LocalPushManager

    init(delegate: LocalPushManagerDelegate) {
        localPushManager = with(LocalPushManager()) {
            $0.delegate = delegate
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pushManagerStateDidChange),
            name: LocalPushManager.stateDidChange,
            object: localPushManager
        )
    }

    func addObserver(_ handler: @escaping (NotificationManagerLocalPushStatus) -> Void) -> HACancellable {
        let observer = Observer(identifier: UUID(), handler: handler)
        observers.append(observer)
        return HABlockCancellable { [weak self] in
            self?.observers.removeAll(where: { $0.identifier == observer.identifier })
        }
    }

    private struct Observer: Equatable {
        let identifier: UUID
        let handler: (NotificationManagerLocalPushStatus) -> Void

        static func == (lhs: Observer, rhs: Observer) -> Bool {
            lhs.identifier == rhs.identifier
        }
    }

    private var observers = [Observer]()

    @objc private func pushManagerStateDidChange() {
        let status = status
        for observer in observers {
            observer.handler(status)
        }
    }
}
