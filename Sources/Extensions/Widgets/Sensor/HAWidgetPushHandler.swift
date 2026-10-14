import Shared
import WidgetKit

@available(iOS 26.0, *)
struct HAWidgetPushHandler: WidgetPushHandler {
    static let webhookType = "register_push_subscription"

    /// One push subscription per widget kind. Every entity a kind tracks is
    /// registered under a stable, kind-specific subscription_id so kinds do not
    /// clobber each other's entity sets in core (registration is idempotent on
    /// subscription_id).
    struct Subscription {
        let subscriptionID: String
        let target: String
        let entityIDs: Set<String>
    }

    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        let tokenHex = pushInfo.token.map { String(format: "%02x", $0) }.joined()
        let subscriptions = Self.subscriptions(from: widgets).filter { !$0.entityIDs.isEmpty }

        Current.Log.info("HAWidgetPushHandler: token changed -> \(subscriptions.count) subscription(s)")

        guard !subscriptions.isEmpty else {
            Current.Log.info("HAWidgetPushHandler: no trackable entities, skipping register")
            return
        }
        guard !Current.servers.all.isEmpty else {
            Current.Log.error("HAWidgetPushHandler: no servers available in extension")
            return
        }

        for server in Current.servers.all {
            for subscription in subscriptions {
                let request = WebhookRequest(
                    type: Self.webhookType,
                    data: [
                        "subscription_id": subscription.subscriptionID,
                        "push_token": tokenHex,
                        "entity_ids": subscription.entityIDs.sorted(),
                        "target": subscription.target,
                    ]
                )
                Current.Log.info(
                    "HAWidgetPushHandler: registering \(subscription.subscriptionID) " +
                        "(\(subscription.entityIDs.count) entities) with \(server.identifier.rawValue)"
                )
                Task {
                    do {
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            Current.webhooks.sendEphemeral(server: server, request: request)
                                .done { continuation.resume() }
                                .catch { continuation.resume(throwing: $0) }
                        }
                    } catch {
                        Current.Log.error(
                            "HAWidgetPushHandler: failed to register \(subscription.subscriptionID) " +
                                "with \(server.identifier.rawValue): \(error)"
                        )
                    }
                }
            }
        }
    }

    /// Collect tracked entity IDs for every push-capable widget kind present,
    /// grouped into one subscription per kind.
    ///
    /// Only kinds whose entities are known at configuration time are included.
    /// Template-driven kinds (gauge, details) render Jinja server-side and have
    /// no fixed entity list, and commonlyUsedEntities is computed dynamically, so
    /// those cannot be expressed as entity subscriptions and are excluded.
    static func subscriptions(from widgets: [WidgetInfo]) -> [Subscription] {
        var entitiesByKind: [WidgetsKind: Set<String>] = [:]

        for info in widgets {
            guard let kind = WidgetsKind(rawValue: info.kind) else { continue }
            switch kind {
            case .sensors:
                if let intent = try? info.widgetConfigurationIntent(of: WidgetSensorsAppIntent.self),
                   let sensors = intent.sensors {
                    entitiesByKind[.sensors, default: []].formUnion(sensors.map(\.entityId))
                }
            case .todoList:
                if let intent = try? info.widgetConfigurationIntent(of: WidgetTodoListAppIntent.self),
                   let entityId = intent.list?.entityId {
                    entitiesByKind[.todoList, default: []].insert(entityId)
                }
            case .custom:
                if let intent = try? info.widgetConfigurationIntent(of: WidgetCustomAppIntent.self),
                   let widgetId = intent.widget?.id,
                   let widget = try? CustomWidget.widgets()?.first(where: { $0.id == widgetId }) {
                    let entityIDs = widget.items
                        .filter { $0.type == .entity }
                        .map(\.id)
                    entitiesByKind[.custom, default: []].formUnion(entityIDs)
                }
            default:
                continue
            }
        }

        return entitiesByKind.map { kind, entityIDs in
            Subscription(
                subscriptionID: "ios-widget-\(kind.rawValue)",
                target: kind.rawValue,
                entityIDs: entityIDs
            )
        }
    }
}
