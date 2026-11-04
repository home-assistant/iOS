import Foundation
@testable import Shared
import Testing
import XCGLogger

struct LogRedactionTests {
    @Test func redactsBearerTokensInRelayedHeaders() {
        let line = #"    Authorization = "Bearer eyJhbGciOiJIUzI1NiJ9.payload.signature-_x";"#

        #expect(LogRedaction.scrub(line) == #"    Authorization = "Bearer <redacted>";"#)
    }

    @Test func redactsWebhookIdInWebSocketJSON() {
        let line = #"Sending: {"type":"mobile_app\/push_notification_channel","webhook_id":"26a1a8424ce649d2"}"#

        #expect(
            LogRedaction.scrub(line) ==
                #"Sending: {"type":"mobile_app\/push_notification_channel","webhook_id":"<redacted>"}"#
        )
    }

    @Test func redactsWebhookIdInUserInfoDump() {
        let line = #"handled command: [AnyHashable("webhook_id"): 26a1a8424ce649d2, AnyHashable("aps"): [:]]"#

        #expect(
            LogRedaction.scrub(line) ==
                #"handled command: [AnyHashable("webhook_id"): <redacted>, AnyHashable("aps"): [:]]"#
        )
    }

    @Test func redactsPushTokenInDictionaryDescription() {
        let line = #"        "push_token" = "caQ67LCjO0q8:APA91bHQ-x_y";"#

        #expect(LogRedaction.scrub(line) == #"        "push_token" = "<redacted>";"#)
    }

    @Test func redactsCloudhookAndWebhookPaths() {
        let cloudhook = "Relayed POST https://hooks.nabu.casa/gAAAAABqrSU8EChk-_= for the watch: 200"
        let webhook = "POST https://ha.example.com/api/webhook/857e94d5bb2f434d9a29aa59eeb81ee4 → 200"
        let escaped = #"{"text":"https:\/\/ha.example.com\/api\/webhook\/abcdef0123"}"#

        #expect(
            LogRedaction.scrub(cloudhook) ==
                "Relayed POST https://hooks.nabu.casa/<redacted> for the watch: 200"
        )
        #expect(LogRedaction.scrub(webhook) == "POST https://ha.example.com/api/webhook/<redacted> → 200")
        #expect(
            LogRedaction.scrub(escaped) ==
                #"{"text":"https:\/\/ha.example.com\/api\/webhook\/<redacted>"}"#
        )
    }

    @Test func redactsWidgetAuthenticityQueryItem() throws {
        let url = try #require(
            URL(string: "homeassistant://navigate/?server=abc&widgetAuthenticity=3359234A-D0A8&more-info=1")
        )

        #expect(
            LogRedaction.scrub(url.absoluteString) ==
                "homeassistant://navigate/?server=abc&widgetAuthenticity=<redacted>&more-info=1"
        )
    }

    @Test func redactsApnsTokenLines() {
        let line = "Successfully registered for push notifications! APNS token: 27d3ed2bb0659913da42"

        #expect(
            LogRedaction.scrub(line) == "Successfully registered for push notifications! APNS token: <redacted>"
        )
    }

    @Test func redactsFirebaseTokensInRegistrationLogs() {
        let refreshed = "Firebase registration token refreshed, new token: caQ67LCjO0q8hCk:APA91bHQXvDO18-K_x"
        let changed = "FCM token has changed from dGVzdA-1_x:APA91bOld_token-1 to caQ67LCjO0q8hCk:APA91bNew-2"

        #expect(LogRedaction.scrub(refreshed) == "Firebase registration token refreshed, new token: <redacted>")
        #expect(LogRedaction.scrub(changed) == "FCM token has changed from <redacted> to <redacted>")
    }

    @Test func leavesNonSecretValuesAlone() {
        let line = #"sending to 857e94d5bb2f434d: ["push_url": "https://example.com/push", "webhook_secret": "x"]"#

        #expect(LogRedaction.scrub(line) == line)
    }

    @Test func redactsSensitiveValuesInNestedDictionaries() throws {
        let value: [String: Any] = [
            "app_data": ["push_token": "abc", "push_url": "https://example.com"],
            "cloudhook_url": "https://hooks.nabu.casa/gAAAA",
            "name": "Kitchen",
        ]

        let redacted = try #require(LogRedaction.scrubValues(in: value) as? [String: Any])
        let appData = try #require(redacted["app_data"] as? [String: Any])

        #expect(appData["push_token"] as? String == LogRedaction.placeholder)
        #expect(appData["push_url"] as? String == "https://example.com")
        #expect(redacted["cloudhook_url"] as? String == LogRedaction.placeholder)
        #expect(redacted["name"] as? String == "Kitchen")
    }

    @Test func redactsSensitiveValuesInUserInfo() throws {
        let userInfo: [AnyHashable: Any] = ["webhook_id": "abc", 1: "kept"]

        let redacted = try #require(LogRedaction.scrubValues(in: userInfo) as? [AnyHashable: Any])

        #expect(redacted["webhook_id"] as? String == LogRedaction.placeholder)
        #expect(redacted[1] as? String == "kept")
    }

    @Test func maskTokenKeepsOnlyTheLastFourCharacters() {
        #expect(LogRedaction.maskToken("27d3ed2bb0659913da42074f") == "<redacted, ends 074f>")
    }

    #if DEBUG
    @Test func debugBuildsLeaveLogsUntouched() {
        let line = "Relayed POST https://hooks.nabu.casa/gAAAAABq for the watch: 200"
        let request = WebhookRequest(
            type: "update_registration",
            data: ["app_data": ["push_token": "caQ67:APA91"]]
        )

        let url = URL(string: "https://hooks.nabu.casa/gAAAAABq")

        #expect(!LogRedaction.isEnabled)
        #expect(LogRedaction.redact(line) == line)
        #expect(url.map { LogRedaction.redact($0) } == "https://hooks.nabu.casa/gAAAAABq")
        #expect(LogRedaction.redactToken("27d3ed2bb0659913") == "27d3ed2bb0659913")
        #expect(LogRedaction.redactValues(in: ["push_token": "caQ67:APA91"]) as? [String: String] == [
            "push_token": "caQ67:APA91",
        ])
        #expect(String(describing: request).contains("caQ67:APA91"))
    }
    #endif

    @Test func redactsRemoteUIHosts() {
        let line = #"connecting using HAConnectionInfo(url: https://abc123def.ui.nabu.casa/api/websocket)"#

        #expect(
            LogRedaction.scrub(line) ==
                #"connecting using HAConnectionInfo(url: https://<remote UI URL>/api/websocket)"#
        )
    }

    @Test func redactsExternalHostsOfObservedServers() {
        let servers = FakeServerManager()
        var info = ServerInfo.fake()
        info.connection.set(address: URL(string: "https://observed-home.example.net:8123"), for: .external)
        servers.add(identifier: "observed", serverInfo: info)
        let observer = LogRedactionServerObserver()
        let line = "Evaluating server trust for: observed-home.example.net, https://observed-home.example.net:8123/api"

        observer.start(observing: servers, isEnabled: false)
        #expect(LogRedaction.scrub(line) == line)

        observer.start(observing: servers, isEnabled: true)
        #expect(
            LogRedaction.scrub(line) ==
                "Evaluating server trust for: <external URL>, https://<external URL>:8123/api"
        )
        #expect(LogRedaction.scrub("https://not-observed-home.example.net") == "https://not-observed-home.example.net")

        servers.removeAll()
        servers.notify()
        #expect(LogRedaction.scrub(line) == line)
    }

    @Test func fileFormatterRedactsWrittenLines() {
        var details = LogDetails(
            level: .info,
            date: Date(),
            message: "",
            functionName: "",
            fileName: "",
            lineNumber: 0
        )
        var message = "Relayed POST https://hooks.nabu.casa/gAAAAABq for the watch: 200"

        LogRedactionFormatter().format(logDetails: &details, message: &message)

        #expect(message == "Relayed POST https://hooks.nabu.casa/<redacted> for the watch: 200")
        #expect(LogRedactionFormatter().debugDescription == "LogRedactionFormatter")
    }
}
