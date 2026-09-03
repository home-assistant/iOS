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

    /// The fake server's version predates the hex-decoded key, so the key is the secret's first
    /// 32 bytes; a 64-character secret satisfies both sides.
    private var secretString: String { String(repeating: "ab", count: 32) }

    private func sendingRegistration() -> WatchDeviceRegistration {
        WatchDeviceRegistration(
            webhookID: "watch-hook",
            webhookSecret: secretString,
            cloudhookURL: nil,
            registeredAt: Date()
        )
    }

    @Test func sendPostsAnEncryptedRequestAndDecodesTheAnswer() async throws {
        let server = Server.fake()
        let registration = sendingRegistration()
        let key = try #require(registration.webhookSecretBytes(version: server.info.version))
        let capture = RequestCapture()

        let response = try await WatchWebhookClient.send(
            type: "register_sensor",
            data: ["unique_id": "battery_level"],
            server: server,
            registration: registration,
            timeout: 5,
            perform: { request, _ in
                capture.request = request
                let sealed = try WebhookPayloadCrypto.encrypt(["success": true], secret: key)
                let body = try JSONSerialization.data(withJSONObject: ["encrypted_data": sealed])
                return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        )

        let request = try #require(capture.request)
        #expect(request.url?.absoluteString == "http://homeassistant.local:8123/api/webhook/watch-hook")
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 5)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == HomeAssistantAPI.userAgent)
        let sent = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(sent["type"] as? String == "register_sensor")
        #expect(sent["encrypted"] as? Bool == true)
        let sealed = try #require(sent["encrypted_data"] as? String)
        let opened = try #require(WebhookPayloadCrypto.decrypt(sealed, secret: key) as? [String: Any])
        #expect(opened["unique_id"] as? String == "battery_level")
        #expect((response as? [String: Any])?["success"] as? Bool == true)
    }

    @Test func sendMapsAGoneRegistration() async throws {
        let server = Server.fake()

        await #expect(throws: WatchWebhookClient.WebhookError.registrationGone) {
            try await WatchWebhookClient.send(
                type: "update_sensor_states",
                data: [],
                server: server,
                registration: sendingRegistration(),
                perform: { request, _ in
                    (Data(), HTTPURLResponse(url: request.url!, statusCode: 410, httpVersion: nil, headerFields: nil)!)
                }
            )
        }
    }

    @Test func sendMapsOtherFailuresToTheirStatus() async throws {
        let server = Server.fake()

        await #expect(throws: WatchWebhookClient.WebhookError.unacceptableStatus(code: 500)) {
            try await WatchWebhookClient.send(
                type: "update_sensor_states",
                data: [],
                server: server,
                registration: sendingRegistration(),
                perform: { request, _ in
                    (Data(), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
                }
            )
        }
    }

    @Test func sendFailsWithoutAnActiveURL() async throws {
        let server = Server.fake { info in
            info.connection = ConnectionInfo(
                externalURL: nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "phone",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
            )
        }

        await #expect(throws: (any Error).self) {
            try await WatchWebhookClient.send(
                type: "update_sensor_states",
                data: [],
                server: server,
                registration: sendingRegistration(),
                perform: { _, _ in
                    Issue.record("should not reach the network without a URL")
                    throw WatchWebhookClient.WebhookError.invalidResponse
                }
            )
        }
    }

    @Test func errorsDescribeThemselves() {
        #expect(WatchWebhookClient.WebhookError.registrationGone.errorDescription?.isEmpty == false)
        #expect(WatchWebhookClient.WebhookError.unacceptableStatus(code: 503).errorDescription?.contains("503") == true)
        #expect(WatchWebhookClient.WebhookError.invalidResponse.errorDescription?.isEmpty == false)
    }

    @Test func encryptedResponseWithoutSecretIsAnError() throws {
        let response = try JSONSerialization.data(withJSONObject: ["encrypted_data": "abc"])

        #expect(throws: WebhookJsonParseError.missingKey) {
            try WatchWebhookClient.responseObject(from: response, secret: nil)
        }
    }
}

/// Holds the request a fake `perform` saw, across the actor hop the client makes.
private final class RequestCapture: @unchecked Sendable {
    var request: URLRequest?
}
