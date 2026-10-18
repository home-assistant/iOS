import Foundation
import ObjectMapper
@testable import Shared
import Testing

struct WebhookRequestEncryptionTests {
    @Test func sealsTheDataForAServerWithASecret() throws {
        // The fake server's version predates the hex-decoded key, so the key is the first 32 bytes.
        let secret = String(repeating: "cd", count: 32)
        let server = Server.fake { info in
            info.connection.webhookSecret = secret
        }
        let request = WebhookRequest(type: "update_sensor_states", data: ["unique_id": "battery_level"])

        let json = Mapper<WebhookRequest>(context: WebhookRequestContext.server(server)).toJSON(request)

        #expect(json["type"] as? String == "update_sensor_states")
        #expect(json["encrypted"] as? Bool == true)
        #expect(json["data"] == nil)
        let sealed = try #require(json["encrypted_data"] as? String)
        let key = try #require(server.info.connection.webhookSecretBytes(version: server.info.version))
        let opened = try #require(WebhookPayloadCrypto.decrypt(sealed, secret: key) as? [String: Any])
        #expect(opened["unique_id"] as? String == "battery_level")
    }

    @Test func sendsPlainDataForAServerWithoutASecret() {
        let server = Server.fake()
        let request = WebhookRequest(type: "register_sensor", data: ["unique_id": "battery_level"])

        let json = Mapper<WebhookRequest>(context: WebhookRequestContext.server(server)).toJSON(request)

        #expect(json["encrypted"] == nil)
        #expect((json["data"] as? [String: Any])?["unique_id"] as? String == "battery_level")
    }
}
