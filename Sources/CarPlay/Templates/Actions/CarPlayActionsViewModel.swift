import Foundation
import HAKit
import RealmSwift
import Shared

final class CarPlayActionsViewModel {
    private var actionsToken: NotificationToken?
    weak var templateProvider: CarPlayActionsTemplate?

    func update() {
        let actions = Current.realm().objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("Scene == nil AND showInCarPlay == true")

        actionsToken?.invalidate()
        actionsToken = actions.observe { [weak self] _ in
            self?.templateProvider?.updateList(for: actions)
        }

        templateProvider?.updateList(for: actions)
    }

    func invalidateActionsToken() {
        actionsToken?.invalidate()
    }

    func handleAction(action: Action, completion: @escaping (Bool) -> Void) {
        guard let server = Current.servers.server(for: action) else {
            completion(false)
            return
        }
        Current.api(for: server).HandleAction(actionID: action.ID, source: .CarPlay).pipe { result in
            switch result {
            case .fulfilled:
                completion(true)
            case let .rejected(error):
                Current.Log.info(error)
                completion(false)
            }
        }
    }

    func sendIntroNotification() {
        let content = UNMutableNotificationContent()
        content.title = L10n.CarPlay.Notification.Action.Intro.title
        content.body = L10n.CarPlay.Notification.Action.Intro.body
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.carPlayActionIntro.rawValue,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Current.Log
                    .info("Error scheduling CarPlay Introduction action notification: \(error.localizedDescription)")
            }
        }
    }
}
