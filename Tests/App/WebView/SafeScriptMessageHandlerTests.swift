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

    @Test func allowsMainFrameMessageFromBracketedIPv6Host() {
        let handler = SafeScriptMessageHandler(
            server: server(internalURL: URL(string: "http://[fd00::abcd]:8123")!),
            delegate: NoOpScriptMessageHandler()
        )

        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "http", host: "[fd00::abcd]", port: 8123))
        #expect(handler.shouldAllowMessage(isMainFrame: true, scheme: "http", host: "fd00::abcd", port: 8123))
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

private func server(internalURL: URL) -> Server {
    var info = ServerInfo(
        name: "IPv6 Server",
        connection: .init(
            externalURL: nil,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook-id",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(exceptions: []),
            connectionAccessSecurityLevel: .undefined
        ),
        token: .init(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiration: Date()
        ),
        version: "2026.4.1"
    )

    return Server(identifier: "ipv6", getter: {
        info
    }, setter: { newInfo in
        info = newInfo
        return true
    })
}

private final class NoOpScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}
