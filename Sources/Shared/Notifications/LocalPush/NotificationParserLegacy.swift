import Foundation

public enum NotificationParserLegacy {
    public static func result(from input: [String: Any]) -> [String: Any] {
        var apnsHeaders: [String: Any] = [
            "apns-push-type": "alert",
        ]
        var apnsPayload: [String: Any] = [
            "aps": [
                "alert": [
                    "body": input["message"],
                ],
                "sound": "default"
            ]
        ]

        return ["payload":["apns": ["headers": apnsHeaders, "payload": apnsPayload]]]
    }
}
