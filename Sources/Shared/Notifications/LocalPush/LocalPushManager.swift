import UserNotifications
import HAKit
import PromiseKit

public class LocalPushManager {
    public init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSubscription),
            name: SettingsStore.connectionInfoDidChange,
            object: nil
        )

        updateSubscription()
    }

    deinit {
        subscription?.cancel()
    }

    var add: (UNNotificationRequest) -> Promise<Void> = { request in
        Promise<Void> { seal in
            UNUserNotificationCenter.current().add(request, withCompletionHandler: seal.resolve)
        }
    }

    struct SubscriptionInstance {
        let token: HACancellable
        let webhookID: String

        func cancel() {
            token.cancel()
        }
    }

    private var subscription: SubscriptionInstance?

    @objc private func updateSubscription() {
        guard let webhookID = Current.settingsStore.connectionInfo?.webhookID else {
            // webhook is invalid, if there is a subscription we remove it
            subscription?.cancel()
            subscription = nil
            return
        }

        guard webhookID != subscription?.webhookID else {
            // webhookID hasn't changed, so we don't need to reset
            return
        }

        let request = HATypedSubscription<LocalPushEvent>(request: .init(
            type: "mobile_app/push_notification_channel",
            data: ["webhook_id": webhookID]
        ))

        subscription?.cancel()
        subscription = .init(
            token: Current.apiConnection.subscribe(
                to: request,
                initiated: { [weak self] result in
                    self?.handle(initiated: result.map { _ in () })
                }, handler: { [weak self] _, value in
                    self?.handle(event: value)
                }
            ),
            webhookID: webhookID
        )
    }

    private func handle(initiated result: Swift.Result<Void, HAError>) {
        switch result {
        case let .failure(error):
            Current.Log.error("failed to subscribe to notifications: \(error)")
            subscription = nil
        case .success:
            Current.Log.info("started")
        }
    }

    private func handle(event: LocalPushEvent) {
        Current.Log.debug("handling \(event)")

        firstly {
            Current.api
        }.then { api in
            NotificationAttachmentManager().content(from: event.content, api: api)
        }.recover { error in
            Current.Log.error("failed to get content, giving default: \(error)")
            return .value(event.content)
        }.then { [add] content -> Promise<Void> in
            add(UNNotificationRequest(identifier: event.identifier, content: content, trigger: nil))
        }.done {
            Current.Log.info("added local notification")
        }.catch { error in
            Current.Log.error("failed to add local notification: \(error)")
        }
    }
}
