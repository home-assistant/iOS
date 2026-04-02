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

        #expect(handler.shouldAllowMessage(isMainFrame: true, host: "external.example.com"))
        #expect(handler.shouldAllowMessage(isMainFrame: true, host: "internal.example.com"))
        #expect(handler.shouldAllowMessage(isMainFrame: true, host: "ui.nabu.casa"))
    }

    @Test func rejectsMessageFromHostOutsideConfiguredServerHosts() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(!handler.shouldAllowMessage(isMainFrame: true, host: "evil.example.com"))
    }

    @Test func rejectsIframeMessageEvenWhenHostIsAllowed() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(!handler.shouldAllowMessage(isMainFrame: false, host: "external.example.com"))
    }
}

private final class NoOpScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}
