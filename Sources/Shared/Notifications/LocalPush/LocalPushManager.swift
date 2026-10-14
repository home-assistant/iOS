import HAKit
import HAKit_PromiseKit
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
    private let notificationCommunicationDecorator: NotificationCommunicationDecorator

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
            if case let .available(received) = state {
                receivedCountAcrossReconnects = received
            }
            NotificationCenter.default.post(name: Self.stateDidChange, object: self)
            reportTransitionIfNeeded(from: oldValue, to: state)
        }
    }

    private var receivedCountAcrossReconnects = 0
    private var pendingTransitionReason: String?
    private var connectionStateToken: NSObjectProtocol?
    private var tokens = [HACancellable]()

    public init(
        server: Server,
        notificationCommunicationDecorator: NotificationCommunicationDecorator =
            NotificationCommunicationDecoratorImpl()
    ) {
        self.server = server
        self.notificationCommunicationDecorator = notificationCommunicationDecorator

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
        if let connectionStateToken {
            NotificationCenter.default.removeObserver(connectionStateToken)
            self.connectionStateToken = nil
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

        observeConnectionState(of: connection)

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
            pendingTransitionReason = String(describing: error)
            state = .unavailable
        case .success:
            Current.Log.info("started")
            state = .available(received: receivedCountAcrossReconnects)
        }
    }

    private func observeConnectionState(of connection: HAConnection) {
        if let connectionStateToken {
            NotificationCenter.default.removeObserver(connectionStateToken)
        }
        connectionStateToken = NotificationCenter.default.addObserver(
            forName: HAConnectionState.didTransitionToStateNotification,
            object: connection,
            queue: nil
        ) { [weak self, weak connection] _ in
            guard let self, let connection else { return }
            handle(connectionState: connection.state)
        }
    }

    private func handle(connectionState: HAConnectionState) {
        guard case let .disconnected(reason) = connectionState, case .available = state else {
            return
        }
        Current.Log.info("connection dropped while subscribed: \(reason)")
        pendingTransitionReason = Self.describe(disconnectReason: reason)
        state = .unavailable
    }

    private static func describe(disconnectReason reason: HAConnectionState.DisconnectReason) -> String {
        switch reason {
        case .disconnected:
            return "disconnected"
        case let .waitingToReconnect(lastError, _, retryCount):
            if let lastError {
                return "\(lastError.localizedDescription) (retry \(retryCount))"
            }
            return "waiting to reconnect (retry \(retryCount))"
        case .rejected:
            return "connection rejected"
        }
    }

    private func reportTransitionIfNeeded(from oldState: State, to newState: State) {
        let reason = pendingTransitionReason
        pendingTransitionReason = nil

        let wasAvailable: Bool
        if case .available = oldState {
            wasAvailable = true
        } else {
            wasAvailable = false
        }
        let isAvailable: Bool
        if case .available = newState {
            isAvailable = true
        } else {
            isAvailable = false
        }
        guard wasAvailable != isAvailable else { return }

        let serverName = server.info.name
        let title: String
        let body: String
        if isAvailable {
            title = L10n.LocalPush.StateNotification.Connected.title
            body = L10n.LocalPush.StateNotification.Connected.body(serverName)
        } else {
            title = L10n.LocalPush.StateNotification.Disconnected.title
            body = L10n.LocalPush.StateNotification.Disconnected.body(serverName, reason ?? "unknown")
        }

        Current.clientEventStore.addEvent(ClientEvent(
            text: title,
            type: .notification,
            payload: [
                "server_id": server.identifier.rawValue,
                "server_name": serverName,
                "reason": reason ?? "",
                "received": receivedCountAcrossReconnects,
            ]
        ))
        Current.notificationDispatcher.send(.init(id: .localPushStateChanged, title: title, body: body))
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
            // A live update only starts/updates the Live Activity via the delegate above, silent
            // or not; it never surfaces a standalone banner (the widget is the only visual
            // feedback, matching NotificationManager.willPresent). The confirm is owned by the
            // live activity presentation path, so it stays deferred here.
            Current.Log.info("local push: Live Activity command, updating activity only, deferring confirm")
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

        Task { [add, notificationCommunicationDecorator] in
            var content = await withCheckedContinuation { continuation in
                Current.notificationAttachmentManager.content(from: baseContent, api: api).done {
                    continuation.resume(returning: $0)
                }
            }
            if let sender = NotificationSenderParser.parse(from: content) {
                content = await notificationCommunicationDecorator.decorate(
                    content: content,
                    sender: sender,
                    api: api
                )
            }
            add(UNNotificationRequest(
                identifier: event.identifier,
                content: content,
                trigger: nil
            )).then {
                confirmReceipt()
            }.done {
                Current.Log.info("added local notification")
            }.catch { error in
                Current.Log.error("failed to add local notification: \(error)")
            }
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
}
