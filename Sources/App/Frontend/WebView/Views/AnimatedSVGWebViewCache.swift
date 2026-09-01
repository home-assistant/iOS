import UIKit

/// Keeps a warm, already-loaded `AnimatedSVGWebView` instance for animated SVGs so the loading logo
/// appears instantly instead of paying WKWebView's web-content-process spin-up and first-paint cost
/// the moment `HomeAssistantStandByView` is shown.
///
/// The warm instance is handed out only while it is unattached. If it is already in a view hierarchy
/// (e.g. two multi-window scenes show the loading logo at once), a fresh instance is created for the
/// second caller, since a single `WKWebView` cannot live in two hierarchies at the same time.
///
/// Whether an instance is still animating after sitting off-screen — unparented between appearances,
/// or unparented since the launch preload — is `AnimatedSVGWebView`'s own problem: it re-checks and
/// recovers itself every time it is attached to a window.
@MainActor
final class AnimatedSVGWebViewCache {
    static let shared = AnimatedSVGWebViewCache()

    private var warmWebViews: [String: AnimatedSVGWebView] = [:]

    private init() {}

    /// Eagerly builds and starts loading the warm web view for `resourceName` (e.g. at app launch) so
    /// it is ready before first use.
    func preload(_ resourceName: String) {
        _ = warmWebView(for: resourceName)
    }

    /// Returns a loaded web view for `resourceName`. Reuses the warm instance when it is free,
    /// otherwise creates and loads a fresh one so it can be parented independently.
    func webView(for resourceName: String) -> AnimatedSVGWebView {
        let warm = warmWebView(for: resourceName)
        guard warm.superview == nil else {
            return AnimatedSVGWebView(resourceName: resourceName)
        }
        return warm
    }

    private func warmWebView(for resourceName: String) -> AnimatedSVGWebView {
        if let existing = warmWebViews[resourceName] {
            return existing
        }
        let webView = AnimatedSVGWebView(resourceName: resourceName)
        warmWebViews[resourceName] = webView
        return webView
    }
}
