@testable import HomeAssistant
import Shared
import Testing
import WebKit

struct SafeScriptMessageHandlerTests {
    @Test func allowsMainFrameMessageFromConfiguredServerHost() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(handler.shouldAllowMessage(isMainFrame: true, host: "external.example.com", port: 443))
        #expect(handler.shouldAllowMessage(isMainFrame: true, host: "internal.example.com", port: 80))
        #expect(handler.shouldAllowMessage(isMainFrame: true, host: "ui.nabu.casa", port: 443))
    }

    @Test func rejectsMessageFromOriginOutsideConfiguredServerOrigins() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(!handler.shouldAllowMessage(isMainFrame: true, host: "evil.example.com", port: 443))
        #expect(!handler.shouldAllowMessage(isMainFrame: true, host: "external.example.com", port: 8123))
    }

    @Test func rejectsIframeMessageEvenWhenHostIsAllowed() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(!handler.shouldAllowMessage(isMainFrame: false, host: "external.example.com", port: 443))
    }
}

private final class NoOpScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}
