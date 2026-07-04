//
//  HAWidgetPushHandler.swift
//  HomeAssistant
//
//  Created by Hariharan on 29/06/26.
//  Copyright © 2026 Home Assistant. All rights reserved.
//


import Shared
import WidgetKit

@available(iOS 26.0, *)
struct HAWidgetPushHandler: WidgetPushHandler {
    static let webhookType = "register_push_subscription"
    static let subscriptionID = "ios-widget-sensors"

    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        let tokenHex = pushInfo.token.map { String(format: "%02x", $0) }.joined()
        Current.Log.info("HAWidgetPushHandler: token changed (\(tokenHex.prefix(8))…), \(widgets.count) widget(s)")

        let entityIDs = Self.entityIDs(from: widgets)
        guard !entityIDs.isEmpty else {
            Current.Log.info("HAWidgetPushHandler: no tracked entities, skipping register")
            return
        }

        let request = WebhookRequest(
            type: Self.webhookType,
            data: [
                "subscription_id": Self.subscriptionID,
                "push_token": tokenHex,
                "entity_ids": Array(entityIDs).sorted(),
                "target": "widget",
            ]
        )

        guard !Current.servers.all.isEmpty else {
            Current.Log.error("HAWidgetPushHandler: no servers available in extension")
            return
        }
        for server in Current.servers.all {
            Current.Log.info("HAWidgetPushHandler: registering with \(server.identifier.rawValue)")
            Task {
                try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    Current.webhooks.sendEphemeral(server: server, request: request)
                        .done { continuation.resume() }
                        .catch { continuation.resume(throwing: $0) }
                }
            }
        }
    }

    static func entityIDs(from widgets: [WidgetInfo]) -> Set<String> {
        var ids: Set<String> = []
        for info in widgets where info.kind == WidgetsKind.sensors.rawValue {
            guard let intent = try? info.widgetConfigurationIntent(of: WidgetSensorsAppIntent.self),
                  let sensors = intent.sensors else { continue }
            ids.formUnion(sensors.map(\.entityId))
        }
        return ids
    }
}
