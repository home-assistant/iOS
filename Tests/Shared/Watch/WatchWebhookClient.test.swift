import Foundation
@testable import Shared
import Testing

struct WatchWebhookClientTests {
    private let secret: [UInt8] = Array(0 ..< 32)
    private let internalURL = URL(string: "http://homeassistant.local:8123")!
    private let externalURL = URL(string: "https://example.duckdns.org")!

    private func registration(cloudhook: Bool) -> WatchDeviceRegistration {
        WatchDeviceRegistration(
            webhookID: "watch-hook",
            webhookSecret: nil,
            cloudhookURL: cloudhook ? URL(string: "https://hooks.nabu.casa/watch-hook") : nil,
            registeredAt: Date()
        )
    }

    @Test func usesWebhookPathOnInternalURL() {
        let url = WatchWebhookClient.webhookURL(
            activeURL: internalURL,
            activeURLType: .internal,
            registration: registration(cloudhook: true)
        )

        #expect(url.absoluteString == "http://homeassistant.local:8123/api/webhook/watch-hook")
    }

    @Test func usesCloudhookAwayFromInternalURL() {
        let url = WatchWebhookClient.webhookURL(
            activeURL: externalURL,
            activeURLType: .external,
            registration: registration(cloudhook: true)
        )

        #expect(url.absoluteString == "https://hooks.nabu.casa/watch-hook")
    }

    @Test func usesCloudhookOnRemoteUI() {
        let url = WatchWebhookClient.webhookURL(
            activeURL: URL(string: "https://example.ui.nabu.casa")!,
            activeURLType: .remoteUI,
            registration: registration(cloudhook: true)
        )

        #expect(url.absoluteString == "https://hooks.nabu.casa/watch-hook")
    }

    @Test func usesWebhookPathWithoutCloudhook() {
        let url = WatchWebhookClient.webhookURL(
            activeURL: externalURL,
            activeURLType: .external,
            registration: registration(cloudhook: false)
        )

        #expect(url.absoluteString == "https://example.duckdns.org/api/webhook/watch-hook")
    }

    @Test func plainBodyWithoutSecret() throws {
        let body = try WatchWebhookClient.body(
            type: "register_sensor",
            data: ["unique_id": "battery_level"],
            secret: nil
        )

        #expect(body["type"] as? String == "register_sensor")
        #expect(body["encrypted"] == nil)
        #expect((body["data"] as? [String: Any])?["unique_id"] as? String == "battery_level")
    }

    @Test func encryptedBodyRoundTripsThroughResponseDecoding() throws {
        let body = try WatchWebhookClient.body(
            type: "update_sensor_states",
            data: [["unique_id": "battery_level", "state": 80]],
            secret: secret
        )

        #expect(body["type"] as? String == "update_sensor_states")
        #expect(body["encrypted"] as? Bool == true)
        #expect(body["data"] == nil)

        // A response sealed the same way is what the server sends back.
        let sealed = try #require(body["encrypted_data"] as? String)
        let response = try JSONSerialization.data(withJSONObject: ["encrypted_data": sealed])
        let decoded = try WatchWebhookClient.responseObject(from: response, secret: secret)
        let array = try #require(decoded as? [[String: Any]])
        #expect(array.first?["unique_id"] as? String == "battery_level")
        #expect(array.first?["state"] as? Int == 80)
    }

    @Test func plainResponseIsReturnedAsIs() throws {
        let response = try JSONSerialization.data(withJSONObject: ["battery_level": ["success": true]])
        let decoded = try WatchWebhookClient.responseObject(from: response, secret: secret)

        #expect((decoded as? [String: [String: Any]])?["battery_level"]?["success"] as? Bool == true)
    }

    @Test func emptyResponseDecodesToVoid() throws {
        let decoded = try WatchWebhookClient.responseObject(from: Data(), secret: secret)

        #expect(decoded is Void)
    }

    @Test func encryptedResponseWithoutSecretIsAnError() throws {
        let response = try JSONSerialization.data(withJSONObject: ["encrypted_data": "abc"])

        #expect(throws: WebhookJsonParseError.missingKey) {
            try WatchWebhookClient.responseObject(from: response, secret: nil)
        }
    }
}
