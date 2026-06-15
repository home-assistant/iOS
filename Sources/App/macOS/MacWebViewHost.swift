// Native macOS WKWebView host (target: App-macOS).
//
// AppKit/SwiftUI counterpart of the iOS `WebViewController`. The HA frontend is
// a web app and `WKWebView` is fully native on macOS, so the macOS shell renders
// the same frontend through an `NSViewRepresentable`. The WebKit configuration
// mirrors `WebViewController.makeWebViewConfiguration()`.

#if os(macOS)
import AppKit
import OSLog
import SwiftUI
@preconcurrency import WebKit

private let log = Logger(subsystem: "io.home-assistant.mac", category: "webview")

/// Posted (e.g. by ⌘R or the toolbar) to reload the active web view.
extension Notification.Name {
    static let macWebReload = Notification.Name("io.home-assistant.mac.reload")
}

/// Navigation tracing via os_log. In DEBUG it also mirrors to a file so headless
/// verification can assert on navigation results (`/tmp/ha-mac-trace.log`).
enum MacTrace {
    static func write(_ message: String) {
        log.info("\(message, privacy: .public)")
        #if DEBUG
        let line = "\(Date()) \(message)\n"
        let path = "/tmp/ha-mac-trace.log"
        if let data = line.data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
        #endif
    }
}

/// SwiftUI wrapper around a native-macOS `WKWebView` that renders a frontend URL.
struct MacWebViewHost: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.makeConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground") // mirror iOS `isOpaque = false`
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        MacTrace.write("makeNSView creating WKWebView, target=\(url.absoluteString)")
        context.coordinator.observeReload(of: webView)
        context.coordinator.load(url, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url, into: webView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Configuration (mirrors WebViewController.makeWebViewConfiguration)

    static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .audio
        // Persistent store so the HA web login (tokens in localStorage/cookies)
        // survives relaunch.
        config.websiteDataStore = .default()

        let userContentController = WKUserContentController()
        userContentController.addUserScript(WKUserScript(
            source: """
                window.addEventListener("error", (e) => {
                    if (window.webkit?.messageHandlers?.logError) {
                        window.webkit.messageHandlers.logError.postMessage({
                            "message": JSON.stringify(e.message),
                            "filename": JSON.stringify(e.filename),
                        });
                    }
                });
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        config.userContentController = userContentController
        // Native macOS always renders the desktop frontend (matches Catalyst).
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        return config
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var loadedURL: URL?
        private weak var webView: WKWebView?

        func observeReload(of webView: WKWebView) {
            self.webView = webView
            NotificationCenter.default.addObserver(
                forName: .macWebReload, object: nil, queue: .main
            ) { [weak self] _ in
                self?.webView?.reload()
            }
        }

        func load(_ url: URL, into webView: WKWebView) {
            guard loadedURL != url else { return }
            loadedURL = url
            webView.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MacTrace.write("✅ finished loading \(webView.url?.absoluteString ?? "?")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            MacTrace.write("❌ navigation failed: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            MacTrace.write("❌ provisional navigation failed: \(error.localizedDescription)")
        }
    }
}
#endif
