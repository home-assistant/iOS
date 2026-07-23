import Shared
import UIKit
import WebKit

/// Keeps warm, already-loaded `WKWebView` instances for animated SVGs so the loading logo
/// appears instantly instead of paying WKWebView's web-content-process spin-up and
/// first-paint cost the moment `HomeAssistantStandByView` is shown.
///
/// Views are keyed by bundle resource name and reused: `AnimatedSVGView` pulls the cached
/// instance rather than building its own. Only one animated SVG per resource is ever on
/// screen at a time, so a single shared instance per resource is safe to reparent.
@MainActor
final class AnimatedSVGWebViewCache {
    static let shared = AnimatedSVGWebViewCache()

    private var webViews: [String: WKWebView] = [:]

    private init() {}

    /// Eagerly builds and starts loading the web view for `resourceName` (e.g. at app launch)
    /// so it is warm before first use.
    func preload(_ resourceName: String) {
        _ = webView(for: resourceName)
    }

    /// Returns the cached web view for `resourceName`, creating and loading it on first access.
    func webView(for resourceName: String) -> WKWebView {
        if let existing = webViews[resourceName] {
            return existing
        }
        let webView = Self.makeWebView()
        Self.loadSVG(named: resourceName, into: webView)
        webViews[resourceName] = webView
        return webView
    }

    private static func makeWebView() -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        // Let taps fall through to the logo dismiss gesture behind the view.
        webView.isUserInteractionEnabled = false
        return webView
    }

    private static func loadSVG(named resourceName: String, into webView: WKWebView) {
        guard
            let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
            let svg = try? String(contentsOf: url, encoding: .utf8) else {
            Current.Log.error("Missing or unreadable animated SVG resource \(resourceName).svg")
            return
        }
        webView.loadHTMLString(html(embedding: svg), baseURL: Bundle.main.bundleURL)
    }

    private static func html(embedding svg: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        html, body { margin: 0; padding: 0; height: 100%; width: 100%; background: transparent; overflow: hidden; }
        body { display: flex; align-items: center; justify-content: center; }
        svg { width: 100%; height: 100%; display: block; }
        </style>
        </head>
        <body>
        \(svg)
        </body>
        </html>
        """
    }
}
