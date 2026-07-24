import Shared
import UIKit
import WebKit

/// Keeps a warm, already-loaded `WKWebView` instance for animated SVGs so the loading logo
/// appears instantly instead of paying WKWebView's web-content-process spin-up and
/// first-paint cost the moment `HomeAssistantStandByView` is shown.
///
/// The warm instance is handed out only while it is unattached. If it is already in a view
/// hierarchy (e.g. two multi-window scenes show the loading logo at once), a fresh instance
/// is created for the second caller, since a single `WKWebView` cannot live in two hierarchies
/// at the same time.
@MainActor
final class AnimatedSVGWebViewCache {
    static let shared = AnimatedSVGWebViewCache()

    private var warmWebViews: [String: WKWebView] = [:]

    private init() {}

    /// Eagerly builds and starts loading the warm web view for `resourceName` (e.g. at app
    /// launch) so it is ready before first use.
    func preload(_ resourceName: String) {
        _ = warmWebView(for: resourceName)
    }

    /// Returns a loaded web view for `resourceName`. Reuses the warm instance when it is free,
    /// otherwise creates and loads a fresh one so it can be parented independently.
    func webView(for resourceName: String) -> WKWebView {
        let warm = warmWebView(for: resourceName)
        guard warm.superview != nil else {
            return warm
        }
        let webView = Self.makeWebView()
        Self.loadSVG(named: resourceName, into: webView)
        return webView
    }

    private func warmWebView(for resourceName: String) -> WKWebView {
        if let existing = warmWebViews[resourceName] {
            return existing
        }
        let webView = Self.makeWebView()
        Self.loadSVG(named: resourceName, into: webView)
        warmWebViews[resourceName] = webView
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
