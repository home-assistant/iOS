@testable import HomeAssistant
import Shared
import Testing
import WebKit

struct SafeScriptMessageHandlerTests {
    @Test func allowsMainFrameMessageFromConfiguredServerOrigin() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "https", host: "external.example.com", port: 443))
        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "http", host: "internal.example.com", port: 80))
        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "https", host: "ui.nabu.casa", port: 443))
    }

    @Test func allowsMainFrameMessageWhenImplicitPortsAreReportedAsZero() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "https", host: "external.example.com", port: 0))
        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "http", host: "internal.example.com", port: 0))
        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "https", host: "ui.nabu.casa", port: 0))
    }

    @Test func rejectsMessageFromOriginOutsideConfiguredServerOrigins() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(!handler.shouldAllowMessage(isMainFrame: true, scheme: "https", host: "evil.example.com", port: 443))
        #expect(!handler.shouldAllowMessage(
            isMainFrame: true,
            scheme: "https",
            host: "external.example.com",
            port: 8123
        ))
        #expect(!handler.shouldAllowMessage(isMainFrame: true, scheme: "http", host: "external.example.com", port: 443))
    }

    @Test func rejectsIframeMessageEvenWhenHostIsAllowed() {
        ServerFixture.reset()
        let handler = SafeScriptMessageHandler(
            server: ServerFixture.withRemoteConnection,
            delegate: NoOpScriptMessageHandler()
        )

        #expect(!handler.shouldAllowMessage(
            isMainFrame: false,
            scheme: "https",
            host: "external.example.com",
            port: 443
        ))
    }
}

private final class NoOpScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}
