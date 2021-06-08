import HAKit
import PromiseKit
import UserNotifications

public protocol LocalPushManagerDelegate: AnyObject {
    func localPushManager(
        _ manager: LocalPushManager,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    )
}

public class LocalPushManager {
    public weak var delegate: LocalPushManagerDelegate?

    public static var stateDidChange: Notification.Name = .init(rawValue: "LocalPushManagerStateDidChange")

    public enum State: Equatable {
        case establishing
        case unavailable
        case available(received: Int)

        mutating func increment(by count: Int = 1) {
            switch self {
            case .establishing, .unavailable:
                self = .available(received: count)
            case let .available(received: originalCount):
                self = .available(received: originalCount + count)
            }
        }
    }

    public var state: State = .establishing {
        didSet {
            NotificationCenter.default.post(name: Self.stateDidChange, object: self)
        }
    }

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
            state = .unavailable
            return
        }

        guard webhookID != subscription?.webhookID else {
            // webhookID hasn't changed, so we don't need to reset
            return
        }

        subscription?.cancel()
        subscription = .init(
            token: Current.apiConnection.subscribe(
                to: .localPush(webhookID: webhookID),
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
            state = .unavailable
        case .success:
            Current.Log.info("started")
            state = .available(received: 0)
        }
    }

    private func handle(event: LocalPushEvent) {
        Current.Log.debug("handling \(event)")

        state.increment()

        delegate?.localPushManager(self, didReceiveRemoteNotification: event.content.userInfo)

        firstly {
            Current.api
        }.then { api in
            Current.notificationAttachmentManager.content(from: event.content, api: api)
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
