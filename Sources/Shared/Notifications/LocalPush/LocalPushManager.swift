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
    public let server: Server
    public weak var delegate: LocalPushManagerDelegate?

    public static let stateDidChange: Notification.Name = .init(rawValue: "LocalPushManagerStateDidChange")

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

    private var tokens = [HACancellable]()

    public init(server: Server) {
        self.server = server

        updateSubscription()
        tokens.append(server.observe { [weak self] _ in
            self?.updateSubscription()
        })
    }

    deinit {
        invalidate()
        tokens.forEach { $0.cancel() }
    }

    public func invalidate() {
        if let subscription {
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

    private func updateSubscription() {
        let webhookID = server.info.connection.webhookID

        guard webhookID != subscription?.webhookID else {
            // webhookID hasn't changed, so we don't need to reset
            return
        }
        subscription?.cancel()

        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to update subscription")
            return
        }

        subscription = .init(
            token: connection.subscribe(
                to: .localPush(webhookID: webhookID, serverVersion: server.info.version),
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

        let baseContent = event.content(server: server)
        var userInfo = baseContent.userInfo
        let isLiveActivity = Self.isLiveActivityCommand(userInfo)

        Current.notificationHistoryStore.record(NotificationHistoryEntry(
            content: baseContent,
            kind: isLiveActivity ? .liveActivityLocal : .local
        ))

        if isLiveActivity, let confirmID = event.confirmID {
            userInfo[Self.confirmIDUserInfoKey] = confirmID
        }

        delegate?.localPushManager(self, didReceiveRemoteNotification: userInfo)

        if isLiveActivity {
            // The activity itself is updated via the delegate above. Present an alerting banner
            // (sound + haptics) when the update is not silent, so a start/update is noticed;
            // a silent update refreshes the activity quietly. `baseContent` already carries the
            // sound/empty-alert the parser derived from `silent`. Either way the confirm is owned
            // by the live activity presentation path, so it stays deferred here.
            if Self.isSilentLiveActivity(userInfo) {
                Current.Log.info("local push: silent Live Activity command, suppressing banner, deferring confirm")
            } else {
                Current.Log.info("local push: Live Activity command, presenting alert, deferring confirm")
                add(UNNotificationRequest(identifier: event.identifier, content: baseContent, trigger: nil))
                    .done { Current.Log.info("local push: presented Live Activity alert") }
                    .catch { Current.Log.error("local push: failed to present Live Activity alert: \($0)") }
            }
            return
        }

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to handle local push event")
            return
        }

        let confirmReceipt: () -> Promise<Void> = { [subscription] in
            guard let confirmID = event.confirmID, let webhookID = subscription?.webhookID else {
                return .value(())
            }
            return api.connection.send(.localPushConfirm(
                webhookID: webhookID,
                confirmID: confirmID
            )).promise.map { _ in () }
        }

        if Self.isCommand(userInfo) {
            Current.Log.info("local push: handled as command, suppressing banner")
            confirmReceipt().cauterize()
            return
        }

        firstly {
            Current.notificationAttachmentManager.content(from: baseContent, api: api)
        }.recover { error in
            Current.Log.error("failed to get content, giving default: \(error)")
            return .value(baseContent)
        }.then { [add] content -> Promise<Void> in
            add(UNNotificationRequest(identifier: event.identifier, content: content, trigger: nil))
        }.then { () -> Promise<Void> in
            confirmReceipt()
        }.done {
            Current.Log.info("added local notification")
        }.catch { error in
            Current.Log.error("failed to add local notification: \(error)")
        }
    }

    static let confirmIDUserInfoKey = "hass_confirm_id"

    private static func isLiveActivityCommand(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let hadict = userInfo["homeassistant"] as? [String: Any] else { return false }
        return (hadict["live_update"] as? Bool) == true || (hadict["command"] as? String) == "live_activity"
    }

    private static func isCommand(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let hadict = userInfo["homeassistant"] as? [String: Any] else { return false }
        return (hadict["command"] as? String) != nil
    }

    /// Whether a Live Activity update opted out of alerting. Only an explicit `silent: true`
    /// suppresses the sound/haptics; a missing or `false` value alerts like a normal notification.
    private static func isSilentLiveActivity(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let hadict = userInfo["homeassistant"] as? [String: Any] else { return false }
        return (hadict["silent"] as? Bool) == true
    }
}
