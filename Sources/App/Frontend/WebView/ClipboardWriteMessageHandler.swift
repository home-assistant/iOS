import Shared
import UIKit
@preconcurrency import WebKit

/// WKWebView silently no-ops `navigator.clipboard.writeText` from ingress iframes, so this bridge
/// performs the actual pasteboard write and replies afterwards. Deliberately scoped to the ingress
/// path only — ordinary frontend and third-party frames keep WebKit's native clipboard behavior.
final class ClipboardWriteMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    static let messageName = "clipboardWrite"
    static let ingressPathPrefix = "/api/hassio_ingress/"

    /// Patches `navigator.clipboard.writeText` only in ingress documents and falls back to WebKit's
    /// implementation when the native write is refused. In insecure contexts without a Clipboard
    /// API, installs a write-only `navigator.clipboard` so ingress pages can still request a write.
    static var userScript: WKUserScript {
        WKUserScript(
            source: """
            (function() {
                "use strict";
                if (!window.location.pathname.startsWith("\(ingressPathPrefix)")) { return; }
                const handler = window.webkit && window.webkit.messageHandlers
                    && window.webkit.messageHandlers.\(messageName);
                if (!handler) { return; }
                const nativeWrite = function(text) {
                    if (typeof text !== "string") {
                        return Promise.reject(new TypeError("Clipboard text must be a string"));
                    }
                    return handler.postMessage({ text: text });
                };
                const clipboard = navigator.clipboard;
                if (clipboard) {
                    const original = typeof clipboard.writeText === "function"
                        ? clipboard.writeText.bind(clipboard) : null;
                    const patched = function(text) {
                        return nativeWrite(text).catch(function(error) {
                            return original ? original(text) : Promise.reject(error);
                        });
                    };
                    try {
                        Object.defineProperty(clipboard, "writeText", {
                            value: patched,
                            configurable: true,
                            writable: true,
                        });
                    } catch (error) { /* keep WebKit's implementation */ }
                } else {
                    try {
                        Object.defineProperty(navigator, "clipboard", {
                            value: { writeText: nativeWrite },
                            configurable: true,
                        });
                    } catch (error) { /* leave the page without a Clipboard API */ }
                }
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    private let server: Server
    private let writeToPasteboard: (String) -> Void

    init(server: Server, writeToPasteboard: @escaping (String) -> Void = { UIPasteboard.general.string = $0 }) {
        self.server = server
        self.writeToPasteboard = writeToPasteboard
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        handleMessage(
            body: message.body,
            requestURL: message.frameInfo.request.url,
            scheme: message.frameInfo.securityOrigin.protocol,
            host: message.frameInfo.securityOrigin.host,
            port: message.frameInfo.securityOrigin.port,
            replyHandler: replyHandler
        )
    }

    func handleMessage(
        body: Any,
        requestURL: URL?,
        scheme: String,
        host: String,
        port: Int,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        guard Self.isIngressURL(requestURL), shouldAllowMessage(scheme: scheme, host: host, port: port) else {
            replyHandler(nil, "Origin or path is not allowed to write to the clipboard")
            return
        }

        guard let body = body as? [String: Any] else {
            Current.Log.error("clipboardWrite message with unexpected body type: \(type(of: body))")
            replyHandler(nil, "Malformed clipboard message")
            return
        }

        guard let text = body["text"] as? String else {
            Current.Log.error("clipboardWrite message is missing a string text field")
            replyHandler(nil, "Malformed clipboard message")
            return
        }

        let writeAndReply = {
            self.writeToPasteboard(text)
            replyHandler(nil, nil)
        }
        if Thread.isMainThread {
            writeAndReply()
        } else {
            DispatchQueue.main.sync(execute: writeAndReply)
        }
    }

    static func isIngressURL(_ url: URL?) -> Bool {
        url?.path.hasPrefix(ingressPathPrefix) == true
    }

    func shouldAllowMessage(scheme: String, host: String, port: Int) -> Bool {
        ServerOriginValidator(server: server).isAllowedOrigin(scheme: scheme, host: host, port: port)
    }
}
