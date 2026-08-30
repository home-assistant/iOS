@testable import HomeAssistant
import Shared
import Testing
import WebKit

struct ClipboardWriteMessageHandlerTests {
    @Test func writesTextAndRepliesSuccessfullyForIngressFromConfiguredOrigin() {
        ServerFixture.reset()
        var writtenText: String?
        var replyError: String?
        let handler = ClipboardWriteMessageHandler(
            server: ServerFixture.withRemoteConnection,
            writeToPasteboard: { writtenText = $0 }
        )

        handler.handleMessage(
            body: ["text": "copied from Music Assistant"],
            requestURL: URL(string: "https://external.example.com/api/hassio_ingress/music_assistant")!,
            scheme: "https",
            host: "external.example.com",
            port: 443,
            replyHandler: { _, error in replyError = error }
        )

        #expect(writtenText == "copied from Music Assistant")
        #expect(replyError == nil)
    }

    @Test func rejectsOrdinaryFrontendURLWithoutWritingOrReplyingSuccess() {
        ServerFixture.reset()
        var didWrite = false
        var replyError: String?
        let handler = ClipboardWriteMessageHandler(
            server: ServerFixture.withRemoteConnection,
            writeToPasteboard: { _ in didWrite = true }
        )

        handler.handleMessage(
            body: ["text": "should not be copied"],
            requestURL: URL(string: "https://external.example.com/lovelace/music")!,
            scheme: "https",
            host: "external.example.com",
            port: 443,
            replyHandler: { _, error in replyError = error }
        )

        #expect(!didWrite)
        #expect(replyError == "Origin or path is not allowed to write to the clipboard")
    }

    @Test func rejectsIngressFromOriginOutsideConfiguredServerOrigins() {
        ServerFixture.reset()
        var didWrite = false
        var replyError: String?
        let handler = ClipboardWriteMessageHandler(
            server: ServerFixture.withRemoteConnection,
            writeToPasteboard: { _ in didWrite = true }
        )

        handler.handleMessage(
            body: ["text": "should not be copied"],
            requestURL: URL(string: "https://evil.example.com/api/hassio_ingress/music_assistant")!,
            scheme: "https",
            host: "evil.example.com",
            port: 443,
            replyHandler: { _, error in replyError = error }
        )

        #expect(!didWrite)
        #expect(replyError == "Origin or path is not allowed to write to the clipboard")
    }

    @Test func rejectsMalformedIngressMessageWithoutWriting() {
        ServerFixture.reset()
        var didWrite = false
        var replyError: String?
        let handler = ClipboardWriteMessageHandler(
            server: ServerFixture.withRemoteConnection,
            writeToPasteboard: { _ in didWrite = true }
        )

        handler.handleMessage(
            body: ["text": 123],
            requestURL: URL(string: "https://external.example.com/api/hassio_ingress/music_assistant")!,
            scheme: "https",
            host: "external.example.com",
            port: 443,
            replyHandler: { _, error in replyError = error }
        )

        #expect(!didWrite)
        #expect(replyError == "Malformed clipboard message")
    }

    @Test @MainActor func userScriptOnlyInstallsClipboardShimForIngressDocuments() {
        let script = ClipboardWriteMessageHandler.userScript

        #expect(script.injectionTime == .atDocumentStart)
        #expect(!script.isForMainFrameOnly)
        #expect(script.source.contains("window.location.pathname.startsWith(\"/api/hassio_ingress/\")"))
        #expect(script.source.contains("writable: true"))
    }
}
