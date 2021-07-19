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

    public enum State: Equatable, Codable {
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

        private enum PrimitiveState: String, Codable {
            case establishing
            case unavailable
            case available
        }

        private var primitiveState: PrimitiveState {
            switch self {
            case .establishing: return .establishing
            case .unavailable: return .unavailable
            case .available: return .available
            }
        }

        private var primitiveCount: Int? {
            switch self {
            case let .available(received: count): return count
            case .unavailable, .establishing: return nil
            }
        }

        private enum CodingKeys: CodingKey {
            case primitive
            case count
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(primitiveState, forKey: .primitive)
            try container.encode(primitiveCount, forKey: .count)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let primitiveState = try container.decode(PrimitiveState.self, forKey: .primitive)
            let primitiveCount = try container.decode(Int?.self, forKey: .count)

            switch primitiveState {
            case .establishing: self = .establishing
            case .unavailable: self = .unavailable
            case .available: self = .available(received: primitiveCount ?? 0)
            }
        }
    }

    public var state: State = .establishing {
        didSet {
            NotificationCenter.default.post(name: Self.stateDidChange, object: self)
        }
    }

    public init() {
        updateSubscription()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSubscriptionFromNotification),
            name: SettingsStore.connectionInfoDidChange,
            object: nil
        )
    }

    deinit {
        invalidate()
    }

    public func invalidate() {
        if let subscription = subscription {
            Current.Log.info("cancelling")
            subscription.cancel()
        } else {
            Current.Log.info("no active subscription")
        }
        NotificationCenter.default.removeObserver(self)
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
            Current.Log.info("cancelling subscription")
            token.cancel()
        }
    }

    private var subscription: SubscriptionInstance?

    @objc private func updateSubscriptionFromNotification() {
        DispatchQueue.main.async { [self] in
            updateSubscription()
        }
    }

    private func updateSubscription() {
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
