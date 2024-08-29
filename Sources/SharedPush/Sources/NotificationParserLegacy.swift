import Foundation

// swiftlint:disable cyclomatic_complexity

public struct LegacyNotificationParserResult {
    public init(headers: [String: Any], payload: [String: Any]) {
        self.headers = headers
        self.payload = payload
    }

    public var headers: [String: Any]
    public var payload: [String: Any]
}

public protocol LegacyNotificationParser {
    func result(
        from input: [String: Any],
        defaultRegistrationInfo: @autoclosure () -> [String: String]
    ) -> LegacyNotificationParserResult
}

public struct LegacyNotificationParserImpl: LegacyNotificationParser {
    public var pushSource: String
    public init(pushSource: String) {
        self.pushSource = pushSource
    }

    private struct CommandPayload {
        let isAlert: Bool
        let payload: [String: Any]

        init(_ name: String, aps: [String: Any] = [:], homeassistant: [String: Any] = [:]) {
            self.init(
                isAlert: false,
                payload: [
                    "aps": ["contentAvailable": true].merging(aps, uniquingKeysWith: { a, _ in a }),
                    "homeassistant": ["command": name].merging(homeassistant, uniquingKeysWith: { a, _ in a }),
                ]
            )
        }

        init(isAlert: Bool, payload: [String: Any]) {
            self.isAlert = isAlert
            self.payload = payload
        }
    }

    public func result(
        from input: [String: Any],
        defaultRegistrationInfo: @autoclosure () -> [String: String]
    ) -> LegacyNotificationParserResult {
        let registrationInfo = input["registration_info"] as? [String: String] ?? defaultRegistrationInfo()
        let data = input["data"] as? [String: Any] ?? [:]
        var headers: [String: Any] = [
            "apns-push-type": "alert",
        ]
        if let apnsHeaders = data["apns_headers"] as? [String: Any] {
            headers.merge(apnsHeaders, uniquingKeysWith: { _, b in b })
        }

        let commandPayload: CommandPayload? = {
            switch LegacyNotificationCommandType(rawValue: input["message"] as? String ?? "") {
            case .locationUpdate, .locationUpdates:
                return .init(LegacyNotificationCommandType.locationUpdate.rawValue)
            case .clearBadge:
                return .init(isAlert: true, payload: ["aps": ["badge": 0]])
            case .clearNotification:
                var homeassistant = [String: Any]()

                if let tag = data["tag"] {
                    homeassistant["tag"] = tag
                }

                if let collapseId = headers["apns-collapse-id"] {
                    homeassistant["collapseId"] = collapseId
                }

                return .init(LegacyNotificationCommandType.clearNotification.rawValue, homeassistant: homeassistant)
            case .updateComplications:
                return .init(LegacyNotificationCommandType.updateComplications.rawValue)
            case .updateWidgets:
                return .init(LegacyNotificationCommandType.updateWidgets.rawValue)
            default: return nil
            }
        }()

        if let commandPayload {
            var payload = commandPayload.payload

            if let push = data["push"] as? [String: Any], let badge = push["badge"] as? Int {
                payload.mutateInside("aps") { aps in
                    if aps["badge"] == nil {
                        aps["badge"] = badge
                    }
                }
            }

            if let webhookId = registrationInfo["webhook_id"] {
                payload["webhook_id"] = webhookId
            }

            return .init(
                headers: ["apns-push-type": commandPayload.isAlert ? "alert" : "background"],
                payload: payload
            )
        }

        var needsCategory = false
        var needsMutableContent = false

        var payload: [String: Any] = [
            "aps": [
                "alert": [
                    "body": input["message"],
                ],
                "sound": "default",
            ],
        ]

        if let actions = data["actions"] {
            needsCategory = true
            payload["actions"] = actions
        }

        if let entityId = data["entity_id"] {
            needsCategory = true
            needsMutableContent = true
            payload["entity_id"] = entityId
        }

        if let actionData = data["action_data"] {
            payload["homeassistant"] = actionData
            needsCategory = true
        }

        if let attachment = data["attachment"] {
            payload["attachment"] = attachment
            needsCategory = true
            needsMutableContent = true
        }

        func addAttachment(key: String, contentType: String) {
            guard let url = data[key] as? String else { return }

            payload.mutateInside("attachment") { attachment in
                if attachment["content-type"] == nil {
                    attachment["content-type"] = contentType
                }

                if attachment["url"] == nil {
                    attachment["url"] = url
                }
            }

            needsCategory = true
            needsMutableContent = true
        }

        addAttachment(key: "video", contentType: "mpeg4")
        addAttachment(key: "image", contentType: "jpeg")
        addAttachment(key: "audio", contentType: "waveformaudio")

        payload["url"] = data["url"]
        payload["shortcut"] = data["shortcut"]
        payload["presentation_options"] = data["presentation_options"]

        payload.mutateInside("aps") { aps in
            aps.mutateInside("alert") { alert in
                if let title = input["title"] as? String {
                    alert["title"] = title
                }

                if let subtitle = data["subtitle"] as? String {
                    alert["subtitle"] = subtitle
                }
            }

            if let push = data["push"] as? [String: Any] {
                aps.merge(push, uniquingKeysWith: { _, b in b })
            }

            if let sound = data["sound"] {
                aps["sound"] = sound
            }

            if (aps["sound"] as? String)?.lowercased() == "none" {
                aps["sound"] = nil
            }

            if let category = aps["category"] as? String {
                aps["category"] = category.uppercased()
            }

            if let group = data["group"] as? String {
                aps["thread-id"] = group
            }

            if needsCategory, aps["category"] == nil {
                aps["category"] = "DYNAMIC"
            }

            if needsMutableContent {
                aps["mutable-content"] = true
            }
        }

        if let webhookId = registrationInfo["webhook_id"] {
            payload["webhook_id"] = webhookId
        }

        if let tag = data["tag"] as? String, headers["apns-collapse-id"] == nil {
            headers["apns-collapse-id"] = tag
        }

        if registrationInfo["os_version"]?.starts(with: "10.15") == true {
            payload.mutateInside("aps") { aps in
                if let sound = aps["sound"] as? String {
                    aps["sound"] = (sound as NSString).deletingPathExtension
                }

                aps.mutateInside("sound") { sound in
                    sound["name"] = (sound["name"] as? NSString)?.deletingPathExtension
                }
            }
        }

        if input["message"] as? String == "delete_alert" {
            payload.mutateInside("aps") { aps in
                aps.mutateInside("alert") { alert in
                    alert["title"] = nil
                    alert["subtitle"] = nil
                    alert["body"] = nil
                }
                aps["sound"] = nil
            }
        }

        if input["message"] as? String == "test_push_source" {
            payload.mutateInside("aps") { aps in
                aps.mutateInside("alert") { alert in
                    alert["title"] = input["message"]
                    alert["body"] = pushSource
                }
            }
        }

        return .init(headers: headers, payload: payload)
    }
}

enum LegacyNotificationCommandType: String {
    case locationUpdate = "request_location_update"
    case locationUpdates = "request_location_updates"
    case clearBadge = "clear_badge"
    case clearNotification = "clear_notification"
    case updateComplications = "update_complications"
    case updateWidgets = "update_widgets"
}

private extension Dictionary where Value == Any {
    mutating func mutate<SomeValue>(
        _ key: Key,
        _ type: SomeValue.Type? = nil,
        default: SomeValue? = nil,
        with transform: (inout SomeValue) -> Void
    ) {
        guard let baseReplacement = self[key] ?? `default` else {
            return
        }

        guard var replacement = baseReplacement as? SomeValue else {
            return
        }

        transform(&replacement)
        self[key] = replacement
    }

    mutating func mutateInside(_ key: Key, with transform: (inout [String: Any]) -> Void) {
        mutate(key, [String: Any].self, default: [String: Any](), with: transform)
    }
}
